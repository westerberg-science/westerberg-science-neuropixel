if ~exist('eye_','var'), error('This demo requires eye signal input. Please set it up or try the simulation mode.'); end
hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

% give names to the TaskObjects defined in the conditions file:
fixation_point = 1;

% scene 1: wait for fixation and hold
fix1 = SingleTarget(eye_);
fix1.Target = fixation_point;
fix1.Threshold = 3;

% FreeThenHold is a secondary processor that receives input from SingleTarget
fth1 = FreeThenHold(fix1);  % The main difference between FreeThenHold and WaitThenHold
fth1.MaxTime = 10000;        % is that FreeThenHold allows fixation breaks, before the hold
fth1.HoldTime = 1000;       % requirement is fulfilled, and WaitThenHold does not.

% PropertyMonitor is added just to show the state of FreeThenHold
pm1 = PropertyMonitor(fth1);
pm1.Dashboard = 3;
pm1.Color = [0.7 0.7 0.7];
pm1.ChildProperty = 'BreakCount';

scene1 = create_scene(pm1,fixation_point);

% task
dashboard(1,'FreeThenHold adapter',[1 1 0]);
dashboard(2,'Unlike WaitThenHold, fixation can be broken multiple times before the hold requirement is fulfilled');
dashboard(pm1.Dashboard,'');
dashboard(4,'');

run_scene(scene1);
if fth1.Success
    dashboard(4,'Holding: Succeeded!',[0 1 0]);
else
    if 0==fth1.BreakCount
        dashboard(4,'Fixaion never attempted!',[1 0 0]);
    else
        dashboard(4,'Holding: Failed',[1 0 0]);
    end
end

idle(1500);
set_iti(500);
