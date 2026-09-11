function tests = testPreprocessSpectrum
%TESTPREPROCESSSPECTRUM Dispatch tests for configured background modes.

tests = functiontests(localfunctions);
end

function testConfiguredBackgroundDispatch(testCase)
methods = ["linear", "shirley", "asls", "tougaard"];
for method = methods
    S = struct();
    S.energyFit = linspace(280, 297, 101).';
    S.intensityFit = 2*ones(size(S.energyFit));
    settings = backgroundSettings(method);
    P = xps.preprocessSpectrum(S, settings);
    verifyEqual(testCase, P.softwareNormalizationScale, 2, "AbsTol", 0);
    verifyEqual(testCase, P.scale, 2, "AbsTol", 0);
    verifyEqual(testCase, P.normalization_method, "max");
    verifyEqual(testCase, P.background_method, method);
    tolerance = 1e-10;
    if method == "asls"
        % Sparse solution of the heavily penalized constant system carries
        % a roughly 2.4e-8 roundoff offset in MATLAB R2025b.
        tolerance = 1e-7;
    end
    verifyEqual(testCase, P.background, ones(size(P.background)), ...
        "AbsTol", tolerance, sprintf("%s constant-signal background", method));
    verifyEqual(testCase, P.y_fit, zeros(size(P.y_fit)), ...
        "AbsTol", tolerance, sprintf("%s constant-signal subtraction", method));
end
end

function testAsLSConfiguredParametersAreRecorded(testCase)
S.energyFit = linspace(280,297,101).';
S.intensityFit = 2*ones(size(S.energyFit));
settings = backgroundSettings("asls");
P = xps.preprocessSpectrum(S,settings);
verifyEqual(testCase, P.background_parameters.lambda, 1e6, "AbsTol", 0);
verifyEqual(testCase, P.background_parameters.p, 0.01, "AbsTol", 0);
verifyEqual(testCase, P.background_parameters.iterations, 20, "AbsTol", 0);
end

function settings = backgroundSettings(method)
settings = struct("normalization", "max", "background", method, ...
    "linear_n_points", 5, "shirley_n_points", 5, ...
    "shirley_max_iterations", 50, "shirley_tolerance", 1e-5, ...
    "asls_lambda", 1e6, "asls_p", 0.01, "asls_iterations", 20, ...
    "tougaard_B", 2866, "tougaard_C", 1643);
end
