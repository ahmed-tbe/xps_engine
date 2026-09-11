%% Compatibility entry point for the standardized Sample A benchmark.
% The analysis implementation lives in runSampleABenchmark.m so there is
% only one production-pipeline Sample A report to maintain.

clear; clc; close all;
sampleABenchmarkReport = runSampleABenchmark("linear");
