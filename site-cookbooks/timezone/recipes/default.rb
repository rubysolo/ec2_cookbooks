# set server timezone to US/Pacific

link "/etc/localtime" do
  to "/usr/share/zoneinfo/US/Pacific"
end