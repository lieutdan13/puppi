# Define puppi::project::yum
#
# This is a shortcut define to build a puppi project for the deploy of applications via yum
# If you need to customize it, either change the template defined here or build up your own custom ones.
#
# Variables:
# $rpm - The name of the rpm to install
# $rpm_version - The version to install (default: latest)  
# $install_root - The installation root (default: / )
# $predeploy_customcommand (Optional) -  Full path with arguments of an eventual custom command to execute before the deploy.
#                             The command/script is executed as root, if you need to launch commands as a separated user
#                             manage that inside your custom script
# $predeploy_user (Optional) - The user to be used to execute the $predeploy_customcommand. By default is the same of $user
# $predeploy_priority (Optional) - The priority (execution sequence number) that defines the execution order ot the predeploy command.
#                                  Default: 39 (immediately before the copy of files on the deploy root)
# $postdeploy_customcommand (Optional) - Full path with arguments of an eventual custom command to execute after the deploy.
#                             The command/script is executed as root, if you need to launch commands as a separated user
#                             manage that inside your custom script
# $postdeploy_user (Optional) - The user to be used to execute the $postdeploy_customcommand. By default is the same of $user
# $postdeploy_priority (Optional) - The priority (execution sequence number) that defines the execution order ot the postdeploy command.
#                                  Default: 41 (immediately after the copy of files on the deploy root)
# $disable_services (Optional) - The names (space separated) of the services you might want to stop
#                                during deploy. By default is blank. Example: "apache puppet monit"
# $firewall_src_ip (Optional) - The IP address of a loadbalancer you might want to block during deploy
# $firewall_dst_port (Optional) - The local port to block from the loadbalancer during deploy (Default all)
# $report_email (Optional) - The (space separated) email(s) to notify of deploy/rollback operations
# $backup (Optional) - If and how backups of files are made. Default: "full". Possible values:
#                      "full" - Make full backup of the deploy_root before making the deploy
#                      "diff" - Backup only the files that are going to be deployed. Note that in order to make reliable rollbacks of versions
#                               older that the latest you've to individually rollback every intermediate deploy
#                      "false" - Don not make backups. This disables the option to make rollbacks
# $backup_retention (Optional) - Number of backup archives to keep on the filesystem. (Default 5). Lower if your backups 
#                                are too large and may fill up the filesystem
# $run_checks (Optional) - If you want to run local puppi checks before and after the deploy procedure. Default: "true"
# $checks_required (Optional) - Set to "true" if you wnat to block the installation if preliminary check fail. Default: "false"
# $always_deploy (Optional) - If you always deploy what has been downloaded. Default="yes", if set to "no" a checksum is made between the files
#                             previously downloaded and the new files. If they are the same the deploy is not done.
#
define puppi::project::yum (
    $rpm,
    $rpm_version="latest",
    $install_root="/",
    $predeploy_customcommand="",
    $predeploy_user="",
    $predeploy_priority="39",
    $postdeploy_customcommand="",
    $postdeploy_user="",
    $postdeploy_priority="41",
    $disable_services="",
    $firewall_src_ip="",
    $firewall_dst_port="0",
    $report_email="",
    $backup="full",
    $backup_retention="5",
    $run_checks="true",
    $checks_required="false",
    $always_deploy="yes",
    $enable = 'true' ) {

    require puppi::params

    # Autoinclude the puppi class
    include puppi

    # Set default values
    $predeploy_real_user = $predeploy_user ? {
        ''      => $user,
	default => $predeploy_user,
    }

    $postdeploy_real_user = $postdeploy_user ? {
        ''      => $user,
	default => $postdeploy_user,
    }

    $real_always_deploy = $always_deploy ? {
        "no"    => "no",
        "false" => "no",
        false   => "no",
        "yes"   => "yes",
        "true"  => "yes",
        true    => "yes",
    }

    $real_checks_required = $checks_required ? {
        "no"    => "no",
        "false" => "no",
        false   => "no",
        "yes"   => "yes",
        "true"  => "yes",
        true    => "yes",
    }

# Create Project
    puppi::project { $name: enable => $enable }

# Common Defines
    puppi::deploy {
        "${name}-Deploy":
             priority => "40" , command => "yum.sh" , arguments => "-a deploy -n ${rpm} -r ${install_root} -v ${rpm_version}" ,
             user => "root" , project => "$name" , enable => $enable;
    }

    puppi::rollback {
        "${name}-Rollback":
             priority => "40" , command => "yum.sh" , arguments => "-a rollback -n ${rpm} -r ${install_root} -v ${rpm_version}" ,
             user => "root" , project => "$name" , enable => $enable;
    }


# Run PRE and POST automatic checks
if ($run_checks == "true") {
    puppi::deploy {
        "${name}-Run_PRE-Checks":
             priority => "10" , command => "check_project.sh" , arguments => "$name $real_checks_required" ,
             user => "root" , project => "$name" , enable => $enable;
        "${name}-Run_POST-Checks":
             priority => "80" , command => "check_project.sh" , arguments => "$name" ,
             user => "root" , project => "$name" , enable => $enable ;
    }
    puppi::rollback {
        "${name}-Run_POST-Checks":
             priority => "80" , command => "check_project.sh" , arguments => "$name" ,
             user => "root" , project => "$name" , enable => $enable ;
    }
}


# Run predeploy custom script, if defined
if ($predeploy_customcommand != "") {
    puppi::deploy {
        "${name}-Run_Custom_PreDeploy_Script":
             priority => "$predeploy_priority" , command => "execute.sh" , arguments => "$predeploy_customcommand" ,
             user => "$predeploy_real_user" , project => "$name" , enable => $enable;
    }
    puppi::rollback {
        "${name}-Run_Custom_PreDeploy_Script":
             priority => "$predeploy_priority" , command => "execute.sh" , arguments => "$predeploy_customcommand" ,
             user => "$predeploy_real_user" , project => "$name" , enable => $enable;
    }
}


# Run postdeploy custom script, if defined
if ($postdeploy_customcommand != "") {
    puppi::deploy {
        "${name}-Run_Custom_PostDeploy_Script":
             priority => "$postdeploy_priority" , command => "execute.sh" , arguments => "$postdeploy_customcommand" ,
             user => "$postdeploy_real_user" , project => "$name" , enable => $enable;
    }
    puppi::rollback {
        "${name}-Run_Custom_PostDeploy_Script":
             priority => "$postdeploy_priority" , command => "execute.sh" , arguments => "$postdeploy_customcommand" ,
             user => "$postdeploy_real_user" , project => "$name" , enable => $enable;
    }
}


# Disable services during deploy
if ($disable_services != "") {
    puppi::deploy {
        "${name}-Disable_extra_services":
             priority => "37" , command => "service.sh" , arguments => "stop $disable_services" ,
             user => "root" , project => "$name" , enable => $enable;
        "${name}-Enable_extra_services":
             priority => "44" , command => "service.sh" , arguments => "start $disable_services" ,
             user => "root" , project => "$name" , enable => $enable;
    }
    puppi::rollback {
        "${name}-Disable_extra_services":
             priority => "37" , command => "service.sh" , arguments => "stop $disable_services" ,
             user => "root" , project => "$name" , enable => $enable;
        "${name}-Enable_extra_services":
             priority => "44" , command => "service.sh" , arguments => "start $disable_services" ,
             user => "root" , project => "$name" , enable => $enable;
    }
}


# Exclusion from Load Balancer is managed only if $firewall_src_ip is set
if ($firewall_src_ip != "") {
    puppi::deploy {
        "${name}-Load_Balancer_Block":
             priority => "35" , command => "firewall.sh" , arguments => "$firewall_src_ip $firewall_dst_port on" ,
             user => "root" , project => "$name" , enable => $enable;
        "${name}-Load_Balancer_Unblock":
             priority => "45" , command => "firewall.sh" , arguments => "$firewall_src_ip $firewall_dst_port off" ,
             user => "root" , project => "$name" , enable => $enable;
    }
    puppi::rollback {
        "${name}-Load_Balancer_Block":
             priority => "35" , command => "firewall.sh" , arguments => "$firewall_src_ip $firewall_dst_port on" ,
             user => "root" , project => "$name" , enable => $enable;
        "${name}-Load_Balancer_Unblock":
             priority => "45" , command => "firewall.sh" , arguments => "$firewall_src_ip $firewall_dst_port off" ,
             user => "root" , project => "$name" , enable => $enable;
    }
}


# Reporting
if ($report_email != "") {
    puppi::report {
        "${name}-Mail_Notification":
             priority => "20" , command => "report_mail.sh" , arguments => "$report_email" ,
             user => "root" , project => "$name" , enable => $enable ;
    }
}

}