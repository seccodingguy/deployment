#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long;
use Log::Log4perl qw(:easy);
use lib '/opt/swamp/perl5';
use SWAMP::SWAMPUtils;
use SWAMP::Client::AgentClient;
use SWAMP::Client::GatorClient;
use SWAMP::Client::RunControllerClient;
use SWAMP::Client::LaunchPadClient;

# Node Architecture
# -----------------
# Data Server
# 	Services	httpd(stopped), mysql, swamp, iptables
# 	Monitors	swamp_monitor, quartermaster.jar
# 	Scripts		calldorun.pl, killrun.pl, launchviewer.pl, notifyuser.pl
# 	BinScripts	execute_execution_record, kill_run, launch_viewer, notify_user
#
# Submit Node
# 	Services	httpd, condor, swamp, iptables
# 	Monitors	swamp_monitor, AgentMonitor.pl, LaunchPad.pl, agentdispatcher.jar
# 	Scripts		assessmentlauncher, csa_agent_launcher csa_agent.pl csa_HTCondorAgentl.pl domainmonitorlauncher
#
# Exec Node
# 	Services	condor, condor, iptables
# 	Monitors	swamp_monitor, DomainMonitor.pl
# 	Scripts		assessmentTask.pl, cloc-1.60.pl, start_vm, vm_cleanup, vm_output, vrunTask.pl
#
# Web Nodes - web, dir, rws
# 	Services	httpd, mysql(dir) iptables
# 	Monitors
# 	Scripts
#
# Condor Node

sub service_status { my ($service) = @_ ;
	my $result = `service $service status 2>&1`;
	chomp $result;
	print "$service";
	print "\n" if ($service eq 'iptables');
	print "\t<$result>\n";
}

sub show_service_statuses { my ($services, $iptables) = @_ ;
	print "Services\n";
	print "--------\n";
	service_status('httpd') if ($services);
	service_status('mysql') if ($services);
	service_status('condor') if ($services);
	service_status('swamp') if ($services);
	service_status('iptables') if ($iptables);
	print "\n";
}

# quartermaster - data - /opt/swamp/etc/dsmonitor.conf
# agentmonitor - submit - /opt/swamp/etc/submonitor.conf
# launchpad	- submit - /opt/swamp/etc/submonitor.conf
# agentdispatcher - submit - /opt/swamp/etc/submonitor.conf
# domainmonitor - exec - /opt/swamp/etc/execmonitor.conf
# swamp_monitor - data, submit, exec

sub process_status { my ($process, $silent) = @_ ;
	my $result = `ps axo pid,stat,start,time,command | grep $process | grep -v grep 2>&1`;
	chomp $result;
	print "$process" if (! $silent);
	print "\n" if ($result && ! $silent);
	print "\t<$result>\n" if (! $silent);
	my $pid = (split ' ', $result)[0] if ($result);
	return $pid;
}

sub show_swamp_status { my ($silent) = @_ ;
	print "SWAMP Status\n" if (! $silent);
	print "------------\n" if (! $silent);
	my $count = 0;
	my $pid = process_status('quartermaster.jar', $silent);
	$count += 1 if ($pid);
	$pid = process_status('agentdispatcher.jar', $silent);
	$count += 1 if ($pid);
	$pid = process_status('AgentMonitor.pl', $silent);
	$count += 1 if ($pid);
	$pid = process_status('LaunchPad.pl', $silent);
	$count += 1 if ($pid);
	$pid = process_status('DomainMonitor.pl', $silent);
	$count += 1 if ($pid);
	$pid = process_status('swamp_monitor', $silent);
	$count += 1 if ($pid);
	print "$count swamp monitors running\n" if (! $silent);
	print "\n" if (! $silent);
	return $count;
}

sub show_swamp_tasks_status {
	print "SWAMP Task Status\n";
	print "-----------------\n";
	my $count = 0;
	my $pid = process_status('assessmentTask.pl', 0);
	$count += 1 if ($pid);
	$pid = process_status('calldorun.pl', 0);
	$count += 1 if ($pid);
	$pid = process_status('cloc-60.pl', 0);
	$count += 1 if ($pid);
	$pid = process_status('csa_agent.pl', 0);
	$count += 1 if ($pid);
	$pid = process_status('csa_HTCondorAgent.pl', 0);
	$count += 1 if ($pid);
	$pid = process_status('killrun.pl', 0);
	$count += 1 if ($pid);
	$pid = process_status('launchviewer.pl', 0);
	$count += 1 if ($pid);
	$pid = process_status('notifyuser.pl', 0);
	$count += 1 if ($pid);
	$pid = process_status('vrunTask.pl', 0);
	$count += 1 if ($pid);
}

sub QuarterMasterStatus { my ($config) = @_ ;
	my $qmHost = $config->get('quartermasterHost');
	my $qmPort = int( $config->get('quartermasterPort') );
	print "QuarterMaster\n";
	print "\thost $qmHost port: $qmPort\n";
	SWAMP::Client::GatorClient::configureClient($qmHost, $qmPort);
	my $result = SWAMP::Client::GatorClient::listTools();
	print "\tTools: ", $result->{nitems} || '', "\n";
	$result = SWAMP::Client::GatorClient::listPlatforms();
	print "\tPlatforms: ", $result->{nitems} || '', "\n";
}

sub AgentDispatcherStatus { my ($config) = @_ ;
    my $serverPort = $config->get('dispatcherPort');
    my $serverHost = $config->get('dispatcherHost');
	print "AgentDispatcher\n";
	print "\thost $serverHost port: $serverPort\n";
    	SWAMP::Client::RunControllerClient::configureClient($serverHost, $serverPort);
	my $result = SWAMP::Client::RunControllerClient::doRun("");
	print "\tdoRun: $result->{error}\n";
}

sub AgentMonitorStatus { my ($config) = @_ ;
	my $host = $config->get('agentMonitorHost');
	my $port = $config->get('agentMonitorJobPort');
	print "AgentMonitor\n";
	print "\thost $host port: $port\n";
	SWAMP::Client::AgentClient::configureClient($host, $port);
	my $result = SWAMP::Client::AgentClient::serverVersion();
	print "\tVersion: ", $result || '', "\n";
	$result = SWAMP::Client::AgentClient::status();
	print "\tStatus: ", $result->{pid} || '', "\n";
	$result = SWAMP::Client::AgentClient::getSuitableMachines();
	print "\tSuitable Machines: ", (join ',', keys($result)), "\n";
}

sub LaunchPadStatus { my ($config) = @_ ;
	my $host = $config->get('agentMonitorHost');
	my $port = $config->get('agentMonitorPort');
	print "LaunchPad\n";
	print "\thost $host port: $port\n";
	SWAMP::Client::LaunchPadClient::configureClient($host, $port);
	my $result = SWAMP::Client::LaunchPadClient::launchPadCreateID({'execrunid' => ''});
	print "\tUUID: ", $result->{execrunid} || '', "\n";
}

sub CondorStatus {
	my $result = `condor_status`;
	print "Condor Status\n";
	print "-------------\n";
	print $result, "\n";
	$result = `condor_q`;
	print "\nCondor Queue\n";
	print "------------\n";
	print $result, "\n";
}

sub show_libvirt_status {
	my $result = `virsh list --all`;
	print "\nLibvirt Domains\n";
	print "----------------\n";
	print $result, "\n";
}

sub show_monitor_connections { my ($monitors, $all , $quarter, $dispatcher, $agent, $launch) = @_ ;
	print "SWAMP Monitors\n" if ($monitors || $all);
	print "--------------\n" if ($monitors || $all);
	my $config = SWAMP::SWAMPUtils::getSwampConfig();
	QuarterMasterStatus($config) if ($quarter || $monitors || $all);
	AgentDispatcherStatus($config) if ($dispatcher || $monitors || $all);
	AgentMonitorStatus($config) if ($agent || $monitors || $all);
	LaunchPadStatus($config) if ($launch || $monitors || $all);
	print "\n" if ($monitors || $all);
}

sub KillMonitor { my ($monitor) = @_ ;
	my $pid = process_status($monitor, 0);
	if ($pid) {
		print "Killing: $monitor ";
		my $result = `kill -9 $pid`;
		print $result, "\n";
	}
}

sub KillSwamp {
	my $result = `service swamp stop`;
	print "Stop swamp service result: $result\n";
	sleep 5;
	KillMonitor('quartermaster.jar');
	KillMonitor('agentdispatcher.jar');
	KillMonitor('AgentMonitor.pl');
	KillMonitor('LaunchPad.pl');
	KillMonitor('DomainMonitor.pl');
	KillMonitor('swamp_monitor');
	my $count = show_swamp_status(1);
	if ($count) {
		print "$count swamp monitors still running\n";
	}
	else {
		print "All swamp monitors stopped - deleting log files ... ";
		my $result = `\\rm -f /opt/swamp/log/*`;
		print "done - result: $result\n";
		$result = `\\rm -f /opt/swamp/run/.viewerinfo`;
		print "Deleted .viewerinfo file: $result\n";
	}
	show_swamp_tasks_status();
}

sub usage {
	print "usage: $0 -help -all -services -iptables -swamp -task -libvirt -monitors -quarter -dispatcher -agent -launch -condor\n";
	exit;
}

Log::Log4perl::easy_init($ERROR);

usage() if (! @ARGV);

my $help = 0;
my $all = 0;
my $services = 0;
my $swamp = 0;
my $task = 0;
my $libvirt = 0;
my $monitors = 0;
my $quarter = 0;
my $dispatcher = 0;
my $agent = 0;
my $launch = 0;
my $condor = 0;
my $killswamp = 0;
my $iptables = 0;
my $result = GetOptions(
	'help'		=> \$help,
	'all'		=> \$all,
	'services'	=> \$services,
	'iptables'	=> \$iptables,
	'swamp'		=> \$swamp,
	'task'		=> \$task,
	'libvirt'	=> \$libvirt,
	'monitors'	=> \$monitors,
	'quarter'	=> \$quarter,
	'dispatcher'	=> \$dispatcher,
	'agent'		=> \$agent,
	'launch'	=> \$launch,
	'condor'	=> \$condor,
	'killswamp'	=> \$killswamp,
);
usage() if ($help || ! $result);
# $iptables = 1 if ($all);

show_service_statuses($services || $all, $iptables) if ($services || $iptables || $all);
show_swamp_status(0) if ($swamp || $all);
show_swamp_tasks_status() if ($task || $all);
show_libvirt_status() if ($libvirt || $all);
show_monitor_connections($monitors, $all, $quarter, $dispatcher, $agent, $launch);
CondorStatus() if ($condor || $all);
KillSwamp() if ($killswamp);