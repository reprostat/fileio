function resp = isOctave()
% Checks whether Octave is the current running environment.
%
% FORMAT resp = isOctave()
%
% OUTPUT
%   resp - logical variable, true if Octave is detected and false otherwise

    persistent testOctave;
    if isempty(testOctave)
        testOctave = logical(exist('OCTAVE_VERSION', 'builtin'));
    end
    resp = testOctave;
end
