using Sitecore.Configuration;
using Sitecore.Diagnostics;
using Sitecore.Pipelines;
using System;
using System.Threading;

namespace Sitecore.Foundation.SitecoreExtensions.Pipelines
{
    public class CustomThreadPool
    {
        public void Process(PipelineArgs args)
        {
            Log.Info("Sitecore.Foundation.SitecoreExtensions: Running CustomThreadPool.Process method", this);
            setMinThreads();
            Log.Info("Sitecore.Foundation.SitecoreExtensions: Done running CustomThreadPool.Process method", this);
        }

        private void setMinThreads()
        {
            int currentMinWorker, currentMinIOC;
            // Get the current settings.
            ThreadPool.GetMinThreads(out currentMinWorker, out currentMinIOC);
            Log.Info(string.Format("Application_Start (setMinThreads): Current configuration values for IOCP = {0} and WORKER = {1}",
                currentMinIOC, currentMinWorker), this);
            int workerThreads = string.IsNullOrEmpty(Settings.GetSetting("CustomThreadPool.WorkerThreads"))
                ? currentMinWorker
                : Convert.ToInt32(Settings.GetSetting("CustomThreadPool.WorkerThreads"));
            int iocpThreads = string.IsNullOrEmpty(Settings.GetSetting("CustomThreadPool.IocpThreads"))
                ? currentMinWorker
                : Convert.ToInt32(Settings.GetSetting("CustomThreadPool.IocpThreads"));
            // Change the minimum number of worker threads and minimum asynchronous I/O completion threads.
            if (ThreadPool.SetMinThreads(workerThreads, iocpThreads))
            {
                // The minimum number of threads was set successfully.
                Log.Info(string.Format("Application_Start (setMinThreads): New min configuration values set - IOCP = {0} and WORKER threads = {1}",
                    iocpThreads, workerThreads), this);
            }
            else
            {
                // The minimum number of threads was not changed.
                Log.Debug("Application_Start (setMinThreads): The minimum number of threads was not changed", this);
            }
        }
    }
}