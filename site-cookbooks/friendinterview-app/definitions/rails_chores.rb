define :rails_chores, :task => 'chores' do
  
	namespace = params[:name]
  taskname = params[:task]
	rakefile = "#{@node[:rails][:deploy_to]}/current/Rakefile"
	logdir = "#{@node[:rails][:deploy_to]}/shared/log/cron"
	cron_user = "#{@node[:rails][:user]}"
	
	directory logdir do
		owner cron_user
		group "sysadmin"
		recursive true
	end
	
	cron "#{namespace}_minute_chores" do
		minute '*/5'
		command "RAILS_ENV=production rake -f #{rakefile} #{taskname}:every_five_minutes >> #{logdir}/#{namespace}_every_five_minutes.txt"
	  user cron_user
	end
	cron "#{namespace}_hourly_chores" do
		minute '0'
		command "RAILS_ENV=production rake -f #{rakefile} #{taskname}:hourly >> #{logdir}/#{namespace}_hourly.txt"
	  user cron_user
	end
	cron "#{namespace}_daily_chores" do
		minute '01'
		hour '0'
		command "RAILS_ENV=production rake -f #{rakefile} #{taskname}:daily >> #{logdir}/#{namespace}_daily.txt"
		user cron_user
	end
	cron "#{namespace}_weekly_chores" do
		minute '02'
		hour '0'
		weekday '1'
	  command "RAILS_ENV=production rake -f #{rakefile} #{taskname}:weekly >> #{logdir}/#{namespace}_weekly.txt"
		user cron_user
	end
	
end