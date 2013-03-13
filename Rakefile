require 'rake/testtask'
require 'rake/packagetask'
require 'yard'

GEM='ruby-cute'
CUTE_VERSION='0.0.1'


desc "Run tests"
Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/test*.rb']
end

desc "Generate basic Documentation"
YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']
  t.options = ['--title',"Ruby CUTE #{CUTE_VERSION}"]
end

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

task :default => :test

namespace :version do
  desc "New #{GEM} GIT release (v#{CUTE_VERSION})"
  task :release do
    sh "git tag #{GEM_VERSION} -m \"New release: #{CUTE_VERSION}\""
    sh "git push --tag"
  end

  namespace :bump do
    desc "Bump #{GEM} by a major version"
    task :major do
      bump_version(:major)
    end

    desc "Bump #{GEM} by a minor version"
    task :minor do
      bump_version(:minor)
    end

    desc "Bump #{GEM} by a patch version"
    task :patch do
      bump_version(:patch)
    end
  end
end


def bump_version(level)
  version_txt = CUTE_VERSION
  if version_txt =~ /(\d+)\.(\d+)\.(\d+)/
    major = $1.to_i
    minor = $2.to_i
    patch = $3.to_i
  end

  case level
  when :major
    major += 1
    minor = 0
    patch = 0
  when :minor
    minor += 1
    patch = 0
  when :patch
    patch += 1
  end

  new_version = [major,minor,patch].compact.join('.')
  v = File.read(File.join(File.expand_path(File.dirname(__FILE__)),'Rakefile')).chomp
  v.gsub!(/(\d+)\.(\d+)\.(\d+)/,"#{new_version}")
  File.open(File.join(File.expand_path(File.dirname(__FILE__)),'Rakefile'), 'w') do |file|
    file.puts v
  end
end # def:: bump_version(level)
