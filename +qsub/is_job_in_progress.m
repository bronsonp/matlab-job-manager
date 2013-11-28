function e = is_job_in_progress(config_hash)
% IS_JOB_IN_PROGRESS(hash) returns true if the specified job is running.

batch_config = jobmgr.qsub.batch_system_config();
job_dir = fullfile(batch_config.job_root, config_hash);
e = isdir(job_dir);

end
