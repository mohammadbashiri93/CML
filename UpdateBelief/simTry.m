close all; clear all;

% initialize the global variables (mainly contains the biological aspects 
% of the subject, except memory)
InitGlobals()

doGeneralization = false;

% We have some implicit memory saved! and we can retrieve that memory.
% it can be based on textual cue!
memory     = retrieve_memory(1); % (1) is NULL field

% some experiment-specific parameters
exp = Exp_params(1);

% initialize the state space
global Vx; % biological range of Vx
global Vy; % biological range of Vy
Vsize = length(Vx);

% load('training1.mat');
%
sspace = zeros(2, 2, Vsize, Vsize); % state space initialization
sspace(:,1,:,:) = memory.Fmus; % memory retrieval
sspace(:,2,:,:) = memory.Fsigmas; % memory retrieval


% sspace = load('training1.mat');
% sspace = sspace.sspace;

% Compute ideal force field values for each state
idealF = compIdealF(exp.compF, Vx, Vy); 

% Position Information - this is task dependent
startPos  = [0, 0];
targetPos = [0, 10];

% simulation params
dt       = 0.01;    % [s]  -> step size
period   = 2;     % [s]
N        = ceil(period/dt); 
trial_no = 100;

r         = zeros(N,2); % initial position
r_actual  = zeros(N,2);
v         = zeros(N,2); % initial speed
v_actual  = zeros(N,2);
a         = zeros(N,2); % initial acceleration
a_actual  = zeros(N,2);

saveVx = [];
saveVy = [];

% recrod forces
adapt_forces = zeros(2, N, trial_no);
ideal_force  = zeros(2, N);

% here is where the loop should be implemented
figure('units','normalized','outerposition',[0 0 1 1]);
for trials = 1:trial_no
    clf;
    disp('Trial')
    disp(trials)
  
    for i = 2:N

        t = dt*i;

        % Minimizing total jerk
        [r(i,:), v(i,:), a(i,:)] = compMinJerk(startPos, targetPos, period, t);

        % Compute the forcefield
        F_forcefield = exp.compF(v_actual(i-1,:)) .* 1;
        % ideal_force(:, i)  = exp.compF(v_actual(i-1,:));

        % Use the implicit memory to compute the adaptation force
        F_adapt = -useBelief(v_actual(i-1,:), sspace);
        adapt_forces(:, i, trials) = -F_adapt;
        
        % Update position, velocity and acceleration
        [r_actual(i,:), v_actual(i,:), a_actual(i,:)] = updateMinJerk(r(i-1,:), r_actual(i-1,:),...
                                                                      v(i-1,:), v_actual(i-1,:),...
                                                                      a(i-1,:), F_forcefield, F_adapt, dt);
        
        [indx, indy] = findStateInd(v_actual(i-1,:));                               
        % disp(sspace(:,2,indx, indy));  % displaying the mean of forces at the occured point in velocity space
                                                                  
        % Update the implicit memory for the current velocity
        sspace = UpdateBelief(sspace, v_actual(i-1,:), F_forcefield, doGeneralization);        
        
        
        if (mod(i, 10) == 0)
            % Display the trajectory - velocity
            subplot(122); hold on;
            scatter(v_actual(i-1,1), v_actual(i-1,2), 'filled', 'o'); xlim([-15,15]); ylim([-50,50]);
            xlabel('V_{x}'); ylabel('V_{y}');
            
            % Display the trajectory - position
            subplot(121); hold on;
            scatter(r_actual(i,1), r_actual(i,2), 'filled', 'o'); xlim([-10,10]); ylim([-5,15]);
            % draw the start and target points
            scatter(startPos(1), startPos(2), 100, 'filled', 'k');
            scatter(targetPos(1), targetPos(2), 100, 'filled', 'r'); 
            xlabel('X'); ylabel('Y');
            
            title(['trial number: ', num2str(trials)])
            
            drawnow;
            pause(0.01)
            
        end
        
        saveVx = [saveVx v_actual(i-1,1)];
        saveVy = [saveVy v_actual(i-1,2)];

        
    end
end

% force compendaton graphs
load('idealForce1.mat');
figure; plot(adapt_forces(1,:,1)); hold on; plot(ideal_force(1,:));
figure; plot(adapt_forces(1,:,10)); hold on; plot(ideal_force(1,:));
figure; plot(adapt_forces(1,:,20)); hold on; plot(ideal_force(1,:));
figure; plot(adapt_forces(1,:,30)); hold on; plot(ideal_force(1,:));
figure; plot(adapt_forces(1,:,40)); hold on; plot(ideal_force(1,:));
figure; plot(adapt_forces(1,:,50)); hold on; plot(ideal_force(1,:));

% force compensation progression
adapt_forces_area = squeeze(sum(adapt_forces,2));
ideal_force_area  = squeeze(sum(ideal_force,2));
figure; plot(adapt_forces_area(1,:)/ideal_force_area(1)); grid;
xlabel('Trials'); ylabel('Force Compensation');

figure;
hist3([saveVx' saveVy']);

figure;
plot(sqrt(r_actual(:,1).^2 + r_actual(:,2).^2)); hold on
plot(sqrt(v_actual(:,1).^2 + v_actual(:,2).^2));
% plot(sqrt(a_actual(:,1).^2 + a_actual(:,2).^2));
legend('position', 'velocity');
