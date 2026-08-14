function tests = testComposition
%TESTCOMPOSITION Basic regression checks for composition math.

tests = functiontests(localfunctions);
end

function testAtomicPercentConversion(testCase)
FC = 0.5;
F_atpct = FC/(1+FC)*100;
verifyEqual(testCase,F_atpct,100/3,"AbsTol",1e-12);
end

function testCxF(testCase)
FC = 0.48;
x = 1/FC;
verifyEqual(testCase,x,2.08333333333333,"AbsTol",1e-12);
end

function testSensitivityExample(testCase)
AF = 26373.86;
AC = 14970.0161;
SF = 4.4118;
FC = (AF/SF)/(AC/1.0);
F_atpct = FC/(1+FC)*100;
verifyEqual(testCase,F_atpct,28.5374,"AbsTol",1e-3);
end
