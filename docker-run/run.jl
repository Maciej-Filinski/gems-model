using GEMS
using Dates
using TOML
using UUIDs
using GEMS: CSV, DataFrames

function env_bool(name, default)
    value = lowercase(strip(get(ENV, name, string(default))))
    value in ("true", "1", "yes") && return true
    value in ("false", "0", "no") && return false
    error("$name must be true or false; received $(repr(value))")
end

function run_container()
    config = get(ENV, "GEMS_CONFIG", "/opt/GEMS/data/DefaultConf.toml")
    isfile(config) || error("Configuration file not found: $config")
    report = env_bool("GEMS_REPORT", false)
    csv = env_bool("GEMS_CSV", true)
    pop = String(strip(get(ENV, "GEMS_POPULATION", "")))
    settings = String(strip(get(ENV, "GEMS_SETTINGS", "")))
    style = String(strip(get(ENV, "GEMS_RD_STYLE", "")))
    isempty(style) && (style = report ? "DefaultResultData" : "LightRD")
    style in ("LightRD", "DefaultResultData", "EssentialResultData", "OptimisedResultData") ||
        error("Unsupported GEMS_RD_STYLE: $style")
    report && style != "DefaultResultData" &&
        error("For a full report, set GEMS_RD_STYLE=DefaultResultData (or leave it empty).")

    kwargs = Dict{Symbol, Any}(:configfile => config)
    !isempty(pop) && (kwargs[:population] = pop)
    !isempty(settings) && (kwargs[:settingsfile] = settings)
    for (variable, key) in (("GEMS_POP_SIZE", :pop_size), ("GEMS_SEED", :seed))
        value = strip(get(ENV, variable, ""))
        !isempty(value) && (kwargs[key] = parse(Int, value))
    end
    haskey(kwargs, :pop_size) && kwargs[:pop_size] < 1 && error("GEMS_POP_SIZE must be positive")
    !isempty(pop) && haskey(kwargs, :pop_size) &&
        error("GEMS_POP_SIZE applies only to generated populations; leave it empty when using GEMS_POPULATION.")
    ticks = strip(get(ENV, "GEMS_TICKS", ""))
    !isempty(ticks) && (kwargs[:stop_criterion] = TimesUp(limit=parse(Int, ticks)))

    run_id = Dates.format(now(UTC), "yyyy-mm-dd_HH-MM-SS-sss") * "_" * string(uuid4())[1:8]
    out = joinpath("/output", run_id)
    mkpath(out)
    cp(config, joinpath(out, "simulation.toml"))
    # Capture the resolved dependency versions alongside each run.
    cp("/opt/gems-env/Project.toml", joinpath(out, "environment.Project.toml"))
    cp("/opt/gems-env/Manifest.toml", joinpath(out, "environment.Manifest.toml"))
    cp("/opt/gems-env/source.sha256", joinpath(out, "source.sha256"))

    metadata = Dict{String, Any}(
        "started_utc" => string(now(UTC)), "status" => "started",
        "julia_version" => string(VERSION), "threads" => Threads.nthreads(),
        "config" => config, "population" => isempty(pop) ? "generated" : pop,
        "settings" => settings, "result_style" => style,
        "overrides" => Dict(k => v for (k, v) in ENV if startswith(k, "GEMS_")))
    write_metadata() = open(joinpath(out, "runinfo.toml"), "w") do io
        TOML.print(io, metadata)
    end
    write_metadata()
    println("Output directory: $out")
    try
        init_time = @elapsed sim = Simulation(; kwargs...)
        metadata["seed"] = GEMS.seed(sim)
        metadata["initialization_seconds"] = init_time
        metadata["simulation_seconds"] = @elapsed run!(sim; with_progressbar=false)

        raw = joinpath(out, "raw")
        mkpath(raw)
        for (name, logger) in (("infections", infectionlogger(sim)),
                               ("deaths", deathlogger(sim)), ("tests", testlogger(sim)))
            save_JLD2(logger, joinpath(raw, "$name.jld2"))
            csv && GEMS.save(logger, joinpath(raw, "$name.csv"))
        end

        metadata["postprocessing_seconds"] = @elapsed rd = ResultData(sim; style=style)
        processed = joinpath(out, "processed")
        exportJLD(rd, processed)
        exportJSON(rd, processed)
        if csv
            for (name, table) in dataframes(rd)
                table isa DataFrames.AbstractDataFrame || continue
                CSV.write(joinpath(processed, "$name.csv"), table)
            end
        end
        if report
            generate(buildreport(rd), joinpath(out, "report"))
            isfile(joinpath(out, "report", "report.html")) ||
                error("GEMS did not generate report.html; inspect the report directory and container log.")
        end
        metadata["status"] = "completed"
        metadata["finished_utc"] = string(now(UTC))
        write_metadata()
        println("Simulation completed: $out")
    catch err
        metadata["status"] = "failed"
        metadata["error"] = sprint(showerror, err)
        write_metadata()
        rethrow()
    end
end

run_container()
