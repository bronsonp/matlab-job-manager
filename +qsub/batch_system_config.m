function batch_config = batch_system_config()

    batch_config = struct();
    batch_config.job_root = fullfile(getenv('HOME'), 'scratch/cache/matlab-job-manager/qsub/in-progress/');

end
