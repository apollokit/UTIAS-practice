addpath ../common;

trans = 2;
ang = 3;
time = 1;
deltaT = .02;
alphas = zeros(1,6);

n_robots = 1;
[Barcodes, Landmark_Groundtruth, Robots] = loadMRCLAMdataSet(n_robots);
Robots = sampleMRCLAMdataSet(Robots, deltaT);

% initialize time, and pose estimate
t = 0;
% need mean and covariance for the initial pose estimate
poseMean = zeros(3, 1);
poseCov = zeros(3,3);
measurementIndex = 1;

% loop through all odometry and measurement samples
% updating the robot's pose estimate with each step
% reference table 7.2 in Probabilistic Robotics
for i = 1:size(Robots{1}.G(:,1))
    theta = poseMean(3, 1);
    % update time
    t = Robots{i}.O(i, time);
    % update movement vector
    u_t = [Robots{1}.O(i, trans); Robots{i}.O(i, ang)];
    
    % calculate a bunch of commonly used terms
    sin1 = sin(theta + u_t(2) * deltaT);
    cos1 = cos(theta + u_t(2) * deltaT);
    plusSin = (sin(theta) + sin1);
    plusCos = (cos(theta) + cos1);
    minusSin = (sin(theta) - sin1);
    minusCos = (cos(theta) - cos1);
    
    % calculate the movement Jacobian
    G_t = [1 0 ((u_t(1) / u_t(2))*(-1 * plusCos));
           0 1 ((u_t(1) / u_t(2))*(-1 * plusSin));
           0 0 1];
    % calculate motion covariance in control space
    M_t = [(alphas(1) * abs(u_t(1)) + alphas(2) * abs(u_t(2)))^2 0;
           0 (alphas(3) * abs(u_t(1)) + alphas(4) * abs(u_t(2)))^2];
    % calculate Jacobian to transform motion covariance to state space
    V_t = [(-1*plusSin/u_t(2)) (((u_t(1)*minusSin)/(u_t(2)^2))+(u_t(1)*cos1*deltaT)/u_t(2));
           (minusCos/u_t(2)) (((-1*minusCos)/(u_t(2)^2))+(u_t(1)*sin1*deltaT*deltaT)/u_t(2));
           0 deltaT];
    % that was easy, right?
    
    % calculate pose update from odometry
    poseUpdate = [(u_t(1) / u_t(2)) * ((-1 * sin(theta)) + sin1);
                  (u_t(1) / u_t(2)) * (cos(theta) - cos1)
                  u_t(2) * deltaT];
    poseMeanHat = poseMean + poseUpdate;
    poseCovHat = G_t * poseCov * G_t' + V_t * M_t * V_t';
    
    % get standard deviations for measurement noise
    % if these don't change we could move this outside 
    % the surrounding for loop
    % also don't know how to calculate the measurement noise std_dev
    Q_t = [sigma_range^2 0 0;
           0 sigma_bearing^2 0;
           0 0 sigma_id^2];
    
    % build vector of features observed at current time
    if Robots{1}.M(measurementIndex, time) == t
        % ignore measurements to other robots
        if Robots{1}.M(measurementIndex, time) > 5
            range = Robots{1}.M(measurementIndex, 3);
            bearing = Robots{1}.M(measurementIndex, 4);
            id = Robots{1}.M(measurementIndex, 2);
            z = [range;
                 bearing;
                 id];
            measurementIndex = measurementIndex + 1;
        end
    end
    % record additional measurements if more than 
    % one happens at time t
    while Robots{1}.M(measurementIndex, time) == t
        if Robots{1}.M(measurementIndex, time) > 5
            range = Robots{1}.M(measurementIndex, 3);
            bearing = Robots{1}.M(measurementIndex, 4);
            id = Robots{1}.M(measurementIndex, 2);
            nextCol = [range;
                       bearing;
                       id];
            z = [z nextCol];
            measurementIndex = measurementIndex + 1;
        end
    end
    % loop over all features
    % left off at line 9
end