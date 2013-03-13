require 'rake/testtask'
require 'rake/packagetask'

CUTE_VERSION='0.0.1'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/test*.rb']
end

desc "Run tests"
task :default => :test

desc "Generate source tgz package"
Rake::PackageTask::new("ruby-cute",CUTE_VERSION) do |p|
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

