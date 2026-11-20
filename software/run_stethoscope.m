function app = run_stethoscope()
%RUN_STETHOSCOPE  Starts the digital stethoscope dashboard.
%   Open MATLAB, go to this folder, and type:   run_stethoscope
%
%   Needs MATLAB R2024b (works on R2021a or newer). No toolboxes are needed:
%   filtering and segmentation are implemented in this project.
%   The measurement parameters are in assets/measurement_parameters.mat.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'core'));
if isMATLABReleaseOlderThan('R2021a')
    warning('This app was written for MATLAB R2024b; R2021a or newer is required.');
end
app = StethoscopeApp();
if nargout == 0, clear app; end
end
