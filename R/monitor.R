
# == title
# Log for the running/finished/failed job
#
# == param
# -job_id The job id. It can be a single job or a vector of job ids.
# -print Whether print the log message.
# -n_line Number of last lines for each job to show when multiple jobs are queried.
# 
# == value
# The log message as a vector.
job_log = function(job_id, print = TRUE, n_line = 10) {
    
    tb = bjobs(print = FALSE, status = "all")
    
    if(missing(job_id)) {
        tb = bjobs(print = FALSE)
    
        if(is.null(tb)) {
            txt = ("No running job")
            if(print) cat(txt, sep = "\n")
            return(invisible(txt))
        }
        return(job_log(tb[, 1], print = print, n_line = n_line))
    }

    job_id = as.numeric(job_id)

    if(length(job_id) > 1) {
        txt2 = NULL
        for(id in job_id) {
            if(print) qqcat("retrieve log for job @{id}\n")
            txt = job_log(id, print = FALSE)
            if(length(txt) > n_line) {
                txt2 = c(txt2, "\n", paste0(strrep(symbol$double_line, 10), qq(" log for job @{id}, last @{n_line} lines "), strrep(symbol$double_line, 10)))
                txt2 = c(txt2, txt[seq(length(txt) - n_line + 1, length(txt))])
            } else {
                txt2 = c(txt2, "\n", paste0(strrep(symbol$double_line, 10), qq(" log for job @{id} "), strrep(symbol$double_line, 10)))
                txt2 = c(txt2, txt)
            }
        }
        if(print) {
            cat(txt2, sep = "\n")
        }
        return(invisible(txt2))
    }

    # if the job with job_id is not the newest one with the same job name
    job_name = tb$JOB_NAME[tb$JOBID == job_id]
    job_wd = tb$EXEC_CWD[tb$JOBID == job_id]  
    job_queue = tb$QUEUE[tb$JOBID == job_id]  

    if(job_queue == "interactive") {
        txt = qq("Job @{job_id} is an interactive job and has no log.")
        if(print) cat(txt, sep = "\n")
        return(invisible(txt))
    }

    tb_subset = tb[tb$JOB_NAME == job_name & tb$EXEC_CWD == job_wd, , drop = FALSE]
    nrr = nrow(tb_subset)
    if(nrr > 1) {
        tb_subset = tb_subset[order(tb_subset$JOBID), , drop = FALSE]
        if(tb_subset$JOBID[nrr] != job_id) {
            txt = qq("Log file for job @{job_id} has been overwriten by job @{tb_subset$JOBID[nrr]} which is the newest job with the same job name '@{tb_subset$JOB_NAME[nrr]}'.")
            txt = strwrap(txt)
            if(print) cat(txt, sep = "\n")
            return(invisible(txt))
        }
    }

    ln = run_cmd(qq("bjobs -o \"stat output_file\" @{job_id} 2>&1"), print = FALSE)

    if(length(ln) == 1) {
        status = "MISSING"
    }

    ln = ln[-1]  # remove header
    status = gsub("\\s.*$", "", ln)
    output_file = gsub("^\\S+\\s+", "", ln)

    if(status == "MISSING") {
        txt = qq("Cannot find output file for job @{job_id}.")
        if(print) cat(txt, sep = "\n")
        return(invisible(txt))
    } else if(status == "PEND") {
        txt = qq("Job (@{job_id} is still pending.")
        if(print) cat(txt, sep = "\n")
        return(invisible(txt))
    } else if(status == "RUN") {
        # bpeek is slow, we first directly check the temporary output file
        user = bsub_opt$user

        # the temporary job dir
        ln = run_cmd("bparams -a", print = FALSE)
        ind = grep("JOB_SPOOL_DIR", ln)
        if(length(ind)) {
            job_temp_dir = gsub("^\\s*JOB_SPOOL_DIR = ", "", ln[ind])
            job_temp_dir = gsub("/%U$", "", job_temp_dir)
            job_temp_dir = qq("@{job_temp_dir}/@{user}")
        } else {
            remote_home = run_cmd("echo $HOME", print = FALSE)
            job_temp_dir = qq("@{remote_home}/.lsbatch")
        }

        no_file_flag = FALSE
        # check running jobs
        if(on_submission_node()) {
            file = list.files(path = job_temp_dir, pattern = paste0("\\.", job_id, "\\.out"), full.names = TRUE)

            if(length(file) == 0) {
                no_file_flag = TRUE
            } else {
                txt = readLines(file, warn = FALSE)
                txt = c(txt, paste0(symbol$warning, qq(" job (@{job_id}) is still running.")))
                if(print) cat(txt, sep = "\n")
                return(invisible(txt))
            }
        } else {
            # if no such file, ssh_exec gives an error
            oe = try(ln <- ssh_exec(qq("ls @{job_temp_dir}/*.@{job_id}.out")), silent = TRUE)

            if(inherits(oe, "try-error")) {
                no_file_flag = TRUE
            } else if(length(ln) == 0) {
                no_file_flag = TRUE
            } else {
                txt = ssh_exec(qq("cat @{ln}"))
                txt = c(txt, paste0(symbol$warning, qq(" job (@{job_id}) is still running.")))
                if(print) cat(txt, sep = "\n")
                return(invisible(txt))
            }
        }

        if(no_file_flag) {
            ln = run_cmd(qq("bpeek @{job_id}"), print = FALSE)[-1]
            if(length(ln) == 0) {
                txt = qq("Cannot find output file for job (@{job_id}.")
                if(print) cat(txt, sep = "\n")
                return(invisible(txt))
            } else {
                txt = ln
                txt = c(txt, paste0(symbol$warning, qq("\n job (@{job_id}) is still running.")))
                if(print) cat(txt, sep = "\n")
                return(invisible(txt))
            }
        }
    } else {
        no_file_flag = FALSE
        if(on_submission_node()) {
            
            if(!file.exists(output_file)) {
                no_file_flag = TRUE
            } else {
                txt = readLines(output_file, warn = FALSE)
                if(print) cat(txt, sep = "\n")
                return(invisible(txt))
            }
        } else {
            # if no such file, ssh_exec gives an error
            oe = try(ln <- ssh_exec(qq("ls @{output_file}")), silent = TRUE)

            if(inherits(oe, "try-error")) {
                no_file_flag = TRUE
            } else if(length(ln) == 0) {
                no_file_flag = TRUE
            } else {
                txt = ssh_exec(qq("cat @{ln}"))
                if(print) cat(txt, sep = "\n")
                return(invisible(txt))
            }
        }

        if(no_file_flag) {
            txt = qq("Cannot find output file for job (@{job_id}.")
            if(print) cat(txt, sep = "\n")
            return(invisible(txt))
        }
    }
}

on_submission_node = function() {
    Sys.info()["nodename"] %in% bsub_opt$submission_node
}

convert_to_POSIXlt = function(x) {

    if(is.null(bsub_opt$parse_time)) {

        if(all(grepl("^\\w+ \\d+ \\d+:\\d+$", x[1]))) { # Dec 1 18:00
            t = as.POSIXlt(x, format = "%b %d %H:%M")
        } else if(all(grepl("^\\w+ \\d+ \\d+:\\d+:\\d+$", x[1]))) { # Dec 1 18:00:00
            t = as.POSIXlt(x, format = "%b %d %H:%M:%S")
        } else {                                        # Dec 1 18:00:00 2019
            t = as.POSIXlt(x, format = "%b %d %H:%M:%S %Y")
        }
    } else {
        t = bsub_opt$parse_time(x)
    }

    if(any(is.na(t) & x != "-")) {
        stop_wrap(qq("Cannot convert time string (e.g. '@{x[which(is.na(t))[1]]}'') to a `POSIXlt` object. Please set a proper parsing function for `bsub_opt$parse_time`. See ?bsub_opt for more details."))
    }

    if(inherits(t, "POSIXct")) t = as.POSIXlt(t)

    current_t = as.POSIXlt(Sys.time())
    l = t$year > current_t$year
    l[is.na(l)] = FALSE
    if(any(l)) {
        t[l]$year = t[l]$year - 1
    }

    return(t)
}

# == title
# Summary of jobs
# 
# == param
# -status Status of the jobs. Use "all" for all jobs.
# -max Maximal number of recent jobs
# -filter Regular expression to filter on job names
# -print Wether print the table
#
# == details
# There is an additional column "RECENT" which is the order
# for the job with the same name. 1 means the most recent job.
#
# You can directly type ``bjobs`` without parentheses which runs `bjobs` with defaults.
#
# == value
# A data frame with selected job summaries.
#
bjobs = function(status = c("RUN", "PEND"), max = Inf, filter = NULL, print = TRUE) {


    cmd = "bjobs -a -o 'jobid stat job_name queue submit_time start_time finish_time slots mem max_mem dependency exec_cwd delimiter=\",\"' 2>&1"
    ln = run_cmd(cmd, print = FALSE)
    
    # job done or exit
    if(length(ln) == 1) {
        cat(ln, "\n")
        return(invisible(NULL))
    }

    df = read.csv(textConnection(paste(ln, collapse = "\n")), stringsAsFactors = FALSE)
    df$STAT = factor(df$STAT)
    df$SUBMIT_TIME = convert_to_POSIXlt(df$SUBMIT_TIME)
    df$START_TIME = convert_to_POSIXlt(df$START_TIME)
    df$FINISH_TIME = convert_to_POSIXlt(df$FINISH_TIME)
    # running/pending jobs
    df$TIME_PASSED = difftime(Sys.time(), df$START_TIME, units = "hours")
    l = !(df$STAT %in% c("RUN", "PEND"))
    # l[is.na(l)] = FALSE  # finish time is unavailable
    df$TIME_PASSED[l] = difftime(df$FINISH_TIME[l], df$START_TIME[l], units = "hours")
    df$TIME_LEFT = difftime(df$FINISH_TIME, Sys.time(), units = "hours")
    l = df$FINISH_TIME < Sys.time()
    l[is.na(l)] = TRUE
    df$TIME_LEFT[l] = NA

    df$JOBID = as.numeric(df$JOBID)
    df = df[order(df$JOBID), , drop = FALSE]
    tb = table(df$STAT)

    recent = unlist(unname(tapply(df$JOBID, df$JOB_NAME, function(x) {
        structure(order(-x), names = x)
    }, simplify = FALSE)))
    df$RECENT = recent[as.character(df$JOBID)]

    if(! "all" %in% status) {
        df = df[df$STAT %in% status, , drop = FALSE]
    }
    if(!is.null(filter)) {
        df = df[grepl(filter, df$JOB_NAME), , drop = FALSE]
    }
    if(nrow(df)) {
        ind = sort((nrow(df):1)[1:min(c(nrow(df), max))])

        if(!print) {
            return(df[ind, , drop = FALSE])
        }

        df2 = format_summary_table(df[ind, , drop = FALSE])

        max_width = pmax(apply(df2, 2, function(x) max(nchar(x)+1)),
                         nchar(colnames(df2)) + 1)
        ow = getOption("width")
        options(width = sum(max_width) + 10)
        cat(strrep(symbol$line, sum(max_width)), "\n")
        print(df2, row.names = FALSE, right = FALSE)
        if(nrow(df2) > 20) {
            for(i in seq_len(ncol(df2))) {
                nm = colnames(df2)[i]
                cat(" ", nm, sep = "")
                cat(strrep(" ", max_width[i] - nchar(nm) - 1), sep = "")
            }
            cat("\n")
        }
        cat(strrep(symbol$line, sum(max_width)), "\n")
        cat(" ", paste(qq("@{tb} @{names(tb)} job@{ifelse(tb == 1, '', 's')}", collapse = FALSE), collapse = ", "), " within one week.\n", sep = "")
        cat(" You can have more controls by `bjobs(status = ..., max = ..., filter = ...)`.\n")
        options(width = ow)

        return(invisible(df[ind, , drop = FALSE]))
    } else {
        if(!print) {
            return(NULL)
        }

        cat("No job found.\n")
        return(invisible(NULL))
    }
}

class(bjobs) = "bjobs"

convert_to_byte = function(x) {
    num = as.numeric(gsub("\\D", "", x))
    v = ifelse(grepl("K", x), num*1024, ifelse(grepl("M", x), num*1024^2, ifelse(grepl("G", x), num*1024^3, x)))
    suppressWarnings(as.numeric(v))
}

format_summary_table = function(df) {
    df2 = df[, c("JOBID", "STAT", "JOB_NAME", "RECENT","SUBMIT_TIME", "TIME_PASSED", "TIME_LEFT", "SLOTS", "MEM", "MAX_MEM")]

    df2$TIME_PASSED = format_difftime(df2$TIME_PASSED)
    df2$TIME_LEFT = format_difftime(df2$TIME_LEFT)
    df2$MAX_MEM = format_mem(df2$MAX_MEM)
    df2$MEM = format_mem(df2$MEM)

    if(all(df2$RECENT == 1)) {
        df2$RECENT = NULL
    }

    l = nchar(df2$JOB_NAME) > 50
    if(any(l)) {
        foo = substr(df2$JOB_NAME[l], 1, 48)
        foo = paste(foo, "..", sep = "")
        df2$JOB_NAME[l] = foo
    }

    return(df2)
}

format_mem = function(x) {
    gsub(" (.)bytes", "\\1b", x)
}

format_difftime = function(x, add_unit = FALSE) {
    units(x) = "hours"
    t = as.numeric(x)

    hour = floor(t)
    min = floor((t - hour)*60)
    
    l = is.na(x)
    if(add_unit) {
        txt = paste0(hour, "h", ifelse(min < 10, paste0("0", min), min), "m")
    } else {
        txt = paste0(hour, ":", ifelse(min < 10, paste0("0", min), min))
    }
    txt[l] = "-"
    txt[t == 0] = "-"
    txt
}

# == title
# Kill jobs
#
# == param
# -job_id A vector of job ids.
#
bkill = function(job_id) {

    cmd = qq("bkill @{paste(job_id, collapse = ' ')} 2>&1")

    run_cmd(cmd, print = TRUE)
}

# == title
# Run command on submission node
#
# == param
# -cmd A single-line command.
# -print Whether print output from the command.
#
# == details
# If current node is not the submission node, the command is executed via ssh.
#
# == value
# The output of the command
#
run_cmd = function(cmd, print = FALSE) {
    if(on_submission_node()) {
       con = pipe(cmd)
       ln = readLines(con)
       close(con)
    } else {
        ln = ssh_exec(cmd)
    }

    if(print) cat(ln, sep = "\n")
    return(invisible(ln))
}

# == title
# Summary of jobs
#
# == param
# -x a ``bjobs`` class object
# -... other arguments
#
print.bjobs = function(x, ...) {
    x()
}

# == title
# Test whether the jobs are finished
#
# == param
# -job_name A vector of job names
# -output_dir Output dir
#
# == details
# It tests whether the ".done" flag files exist
#
is_job_finished = function(job_name, output_dir = bsub_opt$output_dir) {
    sapply(job_name, function(x) {
        flag_file = qq("@{output_dir}/@{x}.done")
        file.exists(flag_file)
    })
}


# == title
# Wait until all jobs are finished
#
# == param
# -job_name A vector of job names
# -output_dir Output dir
# -wait seconds to wait
#
wait_jobs = function(job_name, output_dir = bsub_opt$output_dir, wait = 30) {
    while(1) {
        finished = is_job_finished(job_name, output_dir)
        if(!all(finished)) {
            job_name = job_name[!finished]
            nj = length(job_name)
            message(qq("still @{nj} job@{ifelse(nj == 1, ' is', 's are')} not finished, wait for @{wait}s."))
            Sys.sleep(wait)
        } else {
            break
        }
    }
    return(invisible(NULL))
}

# == title
# Clear temporary dir
#
# == param
# -ask Whether promote.
#
# == details
# The temporary files might be used by the running/pending jobs. Deleting them might affect some of the jobs.
# You better delete them after all jobs are done.
#
clear_temp_dir = function(ask = TRUE) {
    files = list.files(bsub_opt$temp_dir, full.names = TRUE)
    if(length(files) == 0) {
        if(ask) qqcat("'@{bsub_opt$temp_dir}' is clear.")
        return(invisible(NULL))
    }
    if(!ask) {
        if(length(files)) {
            file.remove(files)
            return(invisible(NULL))
        }
    }

    file_types = gsub("^.*\\.([^.]+)$", "\\1", files)
    tb = table(file_types)
    job_tb = bjobs(status = "all", print = FALSE)
    if(any(job_tb$JOB_STAT %in% c("RUN", "PEND"))) {
        cat("There are still running/pending jobs. Deleting the temporary files might affect some of the jobs.\n")
    }
    cat(qq("There @{ifelse(length(files) > 1, 'are', 'is')} "), qq("@{tb} .@{names(tb)} file@{ifelse(tb > 1, 's', '')}, "), "delete all? [y|n|s] ", sep = "")
    while(1) {
        answer = readline()
        if(answer == "y" || answer == "Y") {
            file.remove(files)
            break
        } else if(answer == "n" || answer == "N") {
            break
        } else if(answer == "s" || answer == "S") {
            for(nm in names(tb)) {
                qqcat("Remove all @{tb[nm]} .@{nm} file@{ifelse(tb[nm] > 1, 's', '')}? [y|n] ")
                while(1) {
                    answer2 = readline()
                    if(answer2 == "y" || answer2 == "Y") {
                        file.remove(files[file_types == nm])
                        break
                    } else if(answer2 == "n" || answer2 == "N") {
                        break
                    } else {
                        qqcat("Remove all @{tb[nm]} .@{nm} file@{ifelse(tb[nm] > 1, 's', '')}? [y|n] ")
                    }
                }
                
            }
            break
        } else {
            cat(qq("There @{ifelse(length(files) > 1, 'are', 'is')} "), qq("@{tb} .@{names(tb)} file@{ifelse(tb > 1, 's', '')}, "), "delete all? [y|n|s] ", sep = "")
        }
    }
    return(invisible(NULL))
}


# == title
# Recent jobs
#
# == param
# -max Maximal number of recent jobs
# -filter Regular expression to filter on job names
#
# == details
# You can directly type ``brecent`` without parentheses which runs `brecent` with defaults.
#   
brecent = function(max = 20, filter = NULL) {
    bjobs(status = "all", max = max, filter = filter)
}
class(brecent) = "bjobs"

# == title
# Running jobs
#
# == param
# -max Maximal number of jobs
# -filter Regular expression to filter on job names
#
# == details
# You can directly type ``bjobs_running`` without parentheses which runs `bjobs_running` with defaults.
#
bjobs_running = function(max = Inf, filter = NULL) {
    bjobs(status = "RUN", max = max, filter = filter)
}
class(bjobs_running) = "bjobs"

# == title
# Pending jobs
#
# == param
# -max Maximal number of jobs
# -filter Regular expression to filter on job names
#
# == details
# You can directly type ``bjobs_pending`` without parentheses which runs `bjobs_pending` with defaults.
#
bjobs_pending = function(max = Inf, filter = NULL) {
    bjobs(status = "PEND", max = max, filter = filter)
}
class(bjobs_pending) = "bjobs"

# == title
# Finished jobs
#
# == param
# -max Maximal number of jobs
# -filter Regular expression to filter on job names
#
# == details
# You can directly type ``bjobs_done`` without parentheses which runs `bjobs_done` with defaults.
#
bjobs_done = function(max = Inf, filter = NULL) {
    bjobs(status = "DONE", max = max, filter = filter)
}
class(bjobs_done) = "bjobs"

# == title
# Failed jobs
#
# == param
# -max Maximal number of jobs
# -filter Regular expression to filter on job names
#
# == details
# You can directly type ``bjobs_exit`` without parentheses which runs `bjobs_exit` with defaults.
#
bjobs_exit = function(max = Inf, filter = NULL) {
    bjobs(status = "EXIT", max = max, filter = filter)
}
class(bjobs_exit) = "bjobs"


# == title
# Job status by name
#
# == param
# -job_name Job name.
# -output_dir The output dir
#
# == value
# If the job is finished, it returns DONE/EXIT/MISSING. If the job is running or pending, it returns the corresponding
# status. If there are multiple jobs with the same name running or pending, it returns a vector.
# 
job_status_by_name = function(job_name, output_dir = bsub_opt$output_dir) {

    ln = run_cmd(qq("bjobs -J @{job_name} 2>&1"), print = FALSE)

    # job done or exit
    if(length(ln) == 1) {
        flag_file = qq("@{output_dir}/@{job_name}.done")
        out_file = qq("@{output_dir}/@{job_name}.out")
        if(file.exists(flag_file)) {
            return("DONE")
        } else if(file.exists(out_file)) {
            return("EXIT")
        } else {
            return("MISSING")
        }
    }

    lt = strsplit(ln, "\\s+")

    lt = lt[-1]
    sapply(lt, "[", 3)
}

# == title
# Job status by id
#
# == param
# -job_id The job id
#
# == value
# If the job has been deleted from the database, it returns MISSING.
# 
job_status_by_id = function(job_id) {

    ln = run_cmd(qq("bjobs -o \"jobid user stat\" @{job_id} 2>&1"), print = FALSE)

    if(length(ln) == 1) {
        return("MISSING")
    }

    lt = strsplit(ln, "\\s+")

    lt = lt[-1]
    sapply(lt, "[", 3)
}

# == title
# A browser-based interactive job monitor 
#
# == details
# The monitor is implemented as a shiny app.
monitor = function() {
    
    if(!on_submission_node()) {
        ssh_validate()
    }

    if(identical(topenv(), asNamespace("bsub"))) {
        shiny::runApp(system.file("app", package = "bsub"))
    } else if(grepl("odcf", Sys.info()["nodename"])) {
        shiny::runApp("/desktop-home/guz/project/development/bsub/inst/app")
    } else if(grepl("w610", Sys.info()["nodename"])) {
        shiny::runApp("~/project/development/bsub/inst/app")
    } else {
        shiny::runApp("~/project/bsub/inst/app")
    }
}

class(monitor) = "bjobs"


# == title
# Check whether there are dump files
#
# == param
# -print Whether print messages
#
# == details
# For the failed jobs, LSF cluster generates a core dump file and R generates a .RDataTmp file.
#
# Note if you manually set working directory in your R code/script, the R dump file can be not caught.
#
check_dump_files = function(print = TRUE) {
    job_tb = bjobs(status = "all", print = FALSE)
    wd = job_tb$EXEC_CWD
    wd = wd[wd != "-"]
    wd = unique(wd)

    dump_files = NULL
    for(w in wd) {
        if(print) {
            qqcat("checking @{w}\n")
        }
        dump_files = c(dump_files, list.files(path = w, pattern = "^core.\\d$", all.files = TRUE, full.names = TRUE))
        dump_files = c(dump_files, list.files(path = w, pattern = "^\\.RDataTmp", all.files = TRUE, full.names = TRUE))
    }

    if(print) {
        if(length(dump_files)) {
            qqcat("found @{length(dump_files)} dump files:\n")
            qqcat("  @{dump_files}\n")
        } else {
            cat("no dump file found\n")
        }
    }

    return(invisible(dump_files))
}


# == title
# Get the dependency of current jobs
#
# == param
# -job_tb A table from `bjobs`. Optional.
#
# == value
# If there is no dependency of all jobs, it returns ``NULl``. If there are dependencies,
# it returns a list of three elements:
#
# -``dep_mat``: a two column matrix containing dependencies from parents to children.
# -``id2name``: a named vector containing mapping from job IDs to job names.
# -``id2stat``: a named vector containing mapping from job IDs to job status.
#
get_dependency = function(job_tb = NULL) {

    if(is.null(job_tb)) job_tb = bjobs(status = "all", print = FALSE)
    
    job_tb = job_tb[, c("JOBID", "STAT", "JOB_NAME", "DEPENDENCY"), drop = FALSE]

    id2name = structure(job_tb$JOB_NAME, names = job_tb$JOBID)
    id2stat = structure(as.character(job_tb$STAT), names = job_tb$JOBID)

    job_tb2 = job_tb[job_tb$DEPENDENCY != "-", , drop = FALSE]
    
    if(nrow(job_tb2) == 0) {
        return(NULL)
    }
    
    dep = lapply(strsplit(job_tb2$DEPENDENCY, " && "), function(x) {
        gsub("^done\\( (\\d+) \\)$", "\\1", x)
    })

    n = sapply(dep, length)
    dep_mat = cbind(parent = as.character(unlist(dep)),
                    child = as.character(rep(job_tb2$JOBID, times = n)))

    all_nodes = unique(dep_mat)
    id2name = id2name[all_nodes]; names(id2name) = all_nodes
    id2stat = id2stat[all_nodes]; names(id2stat) = all_nodes

    return(list(dep_mat = dep_mat, id2name = id2name, id2stat = id2stat))
}

# == title
# Plot the job dependency tree
#
# == param
# -job_id A job ID.
# -job_tb A table from `bjobs`. Optional.
#
plot_dependency = function(job_id, job_tb = NULL) {

    job_id = as.character(job_id)

    job_dep = get_dependency(job_tb = NULL)

    if(is.null(job_dep)) {
        # no dependency
        plot(NULL, xlim = c(0, 1), ylim = c(0, 1), axes = FALSE, ann = FALSE)
        text(0.5, 0.5, qq("no dependency for job @{job_id}"))
        return(invisible(NULL))
    }

    if(!job_id %in% names(job_dep$id2name)) {
        # no dependency
        plot(NULL, xlim = c(0, 1), ylim = c(0, 1), axes = FALSE, ann = FALSE)
        text(0.5, 0.5, qq("no dependency for job @{job_id}"))
        return(invisible(NULL))
    }

    g = igraph::graph.edgelist(job_dep$dep_mat)
    g2 = igraph::graph.edgelist(job_dep$dep_mat, directed = FALSE)

    dist = igraph::distances(g2, v = job_id)

    # node in the connected sub-graph
    nodes = names(which(apply(dist, 2, function(x) any(is.finite(x)))))

    g = igraph::induced_subgraph(g, nodes)

    node_id = igraph::V(g)$name
    n_node = length(node_id)
    node_label = job_dep$id2name[node_id]
    node_label[is.na(node_label)] = "unknown"

    l = nchar(node_label) > 50
    if(any(l)) {
        foo = substr(node_label[l], 1, 48)
        foo = paste(foo, "..", sep = "")
        node_label[l] = foo
    }

    label_width = pmax(nchar(igraph::V(g)$name), nchar(node_label)+2)
    node_label = paste0(igraph::V(g)$name, "\n", "<", node_label, ">")
    node_stat = job_dep$id2stat[igraph::V(g)$name]
    node_stat[is.na(node_stat)] = "unknown"

    stat_col = c("blue", "purple", "black", "red", "grey")
    names(stat_col) = c("RUN", "PEND", "DONE", "EXIT", "unknown") 
    node_color = stat_col[node_stat]
    names(node_color) = node_id
    node_fill = rgb(t(col2rgb(node_color)/255), alpha = 0.2)
    names(node_fill) = node_id

    node_width = (5*label_width - 5)/5/5
    node_height = rep(1, n_node)

    node_shape = rep("rectangle", n_node)

    node_lwd = ifelse(node_id == job_id, 4, 1)

    requireNamespace("graph")
    g2 = new("graphAM", as.matrix(igraph::get.adjacency(g)), edgemode = "directed")

    names(node_width) = node_id
    names(node_height) = node_id
    names(node_label) = node_id
    names(node_shape) = node_id
    names(node_lwd) = node_id
    nAttr = list(width = node_width, height = node_height, label = node_label, shape = node_shape)
    x = Rgraphviz::layoutGraph(g2, nodeAttrs = nAttr)
    graph::nodeRenderInfo(x) = list(color = node_color, fill = node_fill, cex = 1, lwd = node_lwd)
    
    omar = par("mar")
    on.exit(par(mar = omar))

    par(mar = c(6, 0, 0, 0), xpd = NA)
    Rgraphviz::renderGraph(x)

    usr = par("usr")
    legend(x = mean(usr[c(1, 2)]), y = usr[3] - (usr[4] - usr[3])* 0.1, xjust = 0.5, yjust = 1,
        pch = 0, col = stat_col, legend = names(stat_col), 
        pt.cex = 2, bty = "n", ncol = length(stat_col))
}

