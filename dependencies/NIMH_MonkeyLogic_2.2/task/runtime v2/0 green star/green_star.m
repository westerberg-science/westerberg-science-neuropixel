hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

% create a chain of [NullTracker]-[TimeCounter]-[PolygonGraphic]
tc = TimeCounter(null_);
star = PolygonGraphic(tc);

% set the properties of the adapters
tc.Duration = 5000;         % in milliseconds

star.EdgeColor = [0 1 0];   % [r g b]
star.FaceColor = [0 1 0];
star.Size = 2;              % 2 deg by 2 deg
star.Position = [0 0];
star.Vertex = [0.5 1; 0.375 0.625; 0 0.625; 0.25 0.375; 0.125 0; 0.5 0.25; 0.875 0; 0.75 0.375; 1 0.625; 0.625 0.625]; % normalized XY coordinates (0 to 1)

scene = create_scene(star); % call create_scene when the property setting is done

% run scene
run_scene(scene);

idle(50);  % clear screen
