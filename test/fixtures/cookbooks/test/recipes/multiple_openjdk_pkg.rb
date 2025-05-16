openjdk_pkg_install '8' do
  alternatives_priority 1080
  reset_alternatives false
  default false
end

#openjdk_pkg_install '11' do
#  alternatives_priority 1100
#  reset_alternatives false
#end
#
#openjdk_pkg_install '17' do
#  alternatives_priority 1700
#  reset_alternatives false
#  default false
#end
