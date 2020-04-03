import rospy
import yaml
from RelaxedIK.Utils.colors import bcolors

def get_relaxedIK_yaml_obj(path_to_src):
    info_file_loaded = rospy.get_param('relaxedIK/info_file_loaded', default=False)
    print(info_file_loaded)
    if info_file_loaded:
        info_file_name = rospy.get_param('relaxedIK/loaded_info_file_name')
        info_file_path = path_to_src + '/RelaxedIK/Config/info_files/' + info_file_name
        info_file = open(info_file_path, 'r')
        y = yaml.load(info_file)
        return y
    else:
        return None
        # raise Exception(bcolors.WARNING + 'WARNING: info_file not loaded.  Please run [ roslaunch relaxed_ik load_info_file.launch ] with desired properties to load a robot.  If you already did this, ' \
        #                         'try loading again with roscore initialized first.' + bcolors.ENDC)


def get_relaxedIK_yaml_obj_from_info_file_name(path_to_src, info_file_name):
    info_file_path = path_to_src + '/RelaxedIK/Config/info_files/' + info_file_name
    info_file = open(info_file_path, 'r')
    y = yaml.load(info_file)
    return y
