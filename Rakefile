require 'rake/packagetask'
require 'rubygems/package_task'
require 'yard'
require 'rake'
require 'rspec/core/rake_task'
require 'bundler/gem_tasks'

Bundler::GemHelper.install_tasks

GEM='ruby-cute'

def get_version
  File.read(File.join(File.expand_path(File.dirname(__FILE__)), 'VERSION')).chomp
end # def:: get_version

desc "Run spec tests"

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.ruby_opts = "-I lib:spec -w"
  spec.pattern = 'spec/**/*_spec.rb'
end

desc "Generate basic Documentation"

YARD::Rake::YardocTask.new do |t|

t.files   = ['lib/**/*.rb', '-', 'examples/*.rb']
  t.options = ['--title',"Ruby CUTE #{get_version}"]
end

desc "Generate source tgz package"
Rake::PackageTask::new("ruby-cute",get_version) do |p|
  p.need_tar_gz = true
  p.package_files.include('lib/**/*')
  p.package_files.include('ext/**/*')
  p.package_files.include('bin/**/*')
  p.package_files.include('test/**/*')
  p.package_files.include('Rakefile', 'COPYING','README', 'README.md')
end

desc "Builds a Debian package"
task :debian do
  sh 'dpkg-buildpackage -us -uc'
end

desc "Builds a git snapshot package"
task :snapshot do
  sh 'cp debian/changelog debian/changelog.git'
  date = `date --iso=seconds |sed 's/+.*//' |sed 's/[-T:]//g'`.chomp
  sh "sed -i '1 s/)/+git#{date})/' debian/changelog"
  sh 'dpkg-buildpackage -us -uc'
  sh 'mv debian/changelog.git debian/changelog'
end


task :default => :spec
