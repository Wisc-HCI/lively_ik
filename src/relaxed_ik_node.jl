#!/usr/bin/env julia
include("RelaxedIK/relaxedIK.jl")
include("RelaxedIK/GROOVE_RelaxedIK_Julia/relaxedIK_vars.jl")
include("RelaxedIK/Utils_Julia/solver_output.jl")
using YAML
using RobotOS
using Rotations
using BenchmarkTools
using ForwardDiff
using Knet
using Dates
@rosimport relaxed_ik.msg : EEPoseGoals, JointAngles
@rosimport std_msgs.msg: Float64MultiArray, Bool, Float32, Int8
@rosimport geometry_msgs.msg: Point, Quaternion, Pose

rostypegen()
using .relaxed_ik.msg
using .std_msgs.msg
using .geometry_msgs.msg

quit = false
function quit_cb(data::BoolMsg)
    global quit
    quit = data.data
end

reset_solver = false
function reset_cb(data::BoolMsg)
    global reset_solver
    reset_solver = data.data
end

eepg = Nothing
function eePoseGoals_cb(data::EEPoseGoals)
    global eepg
    eepg = data
end

path_to_src = Base.source_dir()
println(path_to_src)
loaded_robot_file = open(path_to_src * "/RelaxedIK/Config/loaded_robot")
loaded_robot = readline(loaded_robot_file)
close(loaded_robot_file)

relaxedIK = get_standard(path_to_src, loaded_robot)
num_chains = relaxedIK.relaxedIK_vars.robot.num_chains

if num_chains == 2
    relaxedIK = get_bimanual(path_to_src, loaded_robot)
elseif num_chains == 3
    relaxedIK = get_3chain(path_to_src, loaded_robot)
elseif num_chains == 4
    relaxedIK = get_4chain(path_to_src, loaded_robot)
elseif num_chains == 5
    relaxedIK = get_5chain(path_to_src, loaded_robot)
end

println("loaded robot: $loaded_robot")

init_node("relaxed_ik_node_jl")

Subscriber{EEPoseGoals}("/relaxed_ik/ee_pose_goals", eePoseGoals_cb)
Subscriber{BoolMsg}("/relaxed_ik/quit", quit_cb)
Subscriber{BoolMsg}("relaxed_ik/reset", reset_cb)
angles_pub = Publisher("/relaxed_ik/joint_angle_solutions", JointAngles, queue_size = 3)

sleep(0.4)

# d = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
# so = Solver_Output(path_to_src, "relaxed_ik", "ur5", d)

eepg = EEPoseGoals()
pose = Pose()
pose.position.x = 0.0
pose.position.y = 0.0
pose.position.z = 0.0
pose.orientation.w = 1.0
pose.orientation.x = 0.0
pose.orientation.y = 0.0
pose.orientation.z = 0.0
for i = 1:num_chains
    push!(eepg.ee_poses, pose)
end
empty_eepg = eepg

loop_rate = Rate(1000)
while ! is_shutdown()
    global quit
    if quit == true
        println("quitting")
        quit = false
        return
    end

    global reset_solver
    global eepg
    global relaxedIK
    if reset_solver == true
        println("resetting")
        reset_solver = false
        # relaxedIK.relaxedIK_vars.vars.xopt = relaxedIK.relaxedIK_vars.vars.init_state
        # relaxedIK.relaxedIK_vars.vars.prev_state = relaxedIK.relaxedIK_vars.vars.init_state
        # relaxedIK.relaxedIK_vars.vars.prev_state2 = relaxedIK.relaxedIK_vars.vars.init_state
        # relaxedIK.relaxedIK_vars.vars.prev_state3 = relaxedIK.relaxedIK_vars.vars.init_state
        relaxedIK = get_standard(path_to_src, loaded_robot)

        if relaxedIK.relaxedIK_vars.robot.num_chains == 2
            relaxedIK = get_bimanual(path_to_src, loaded_robot)
        elseif relaxedIK.relaxedIK_vars.robot.num_chains == 3
            relaxedIK = get_3chain(path_to_src, loaded_robot)
        elseif relaxedIK.relaxedIK_vars.robot.num_chains == 4
            relaxedIK = get_4chain(path_to_src, loaded_robot)
        elseif relaxedIK.relaxedIK_vars.robot.num_chains == 5
            relaxedIK = get_5chain(path_to_src, loaded_robot)
        end
        eepg = empty_eepg
    end

    pose_goals = eepg.ee_poses

    pos_goals = []
    quat_goals = []

    for i = 1:num_chains
        p = pose_goals[i]

        pos_x = p.position.x
        pos_y = p.position.y
        pos_z = p.position.z

        quat_w = p.orientation.w
        quat_x = p.orientation.x
        quat_y = p.orientation.y
        quat_z = p.orientation.z

        push!(pos_goals, [pos_x, pos_y, pos_z])
        push!(quat_goals, Quat(quat_w, quat_x, quat_y, quat_z))
    end

    xopt = solve(relaxedIK, pos_goals, quat_goals)
    # println(relaxedIK.relaxedIK_vars.vars.objective_closures[end](xopt))
    ja = JointAngles()
    for i = 1:length(xopt)
        push!(ja.angles.data, xopt[i])
    end
    publish(angles_pub, ja)

    println(xopt)
    rossleep(loop_rate)
end
