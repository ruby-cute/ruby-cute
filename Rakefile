require 'rake/testtask'
require 'rake/packagetask'
require 'rubygems/package_task'
require 'yard'
require 'rake'
require 'rspec/core/rake_task'
GEM='ruby-cute'

def get_version
  File.read(File.join(File.expand_path(File.dirname(__FILE__)), 'VERSION')).chomp
end # def:: get_version



desc "Run spec tests"
RSpec::Core::RakeTask.new(:spec)

desc "Run tests"
Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/test*.rb']
end

desc "Generate basic Documentation"
YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']
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

task :default => :test

namespace :version do
  desc "New #{GEM} GIT release (v#{get_version})"
  task :release do
    sh "git tag #{get_version} -m \"New release: #{get_version}\""
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
  version_txt = get_version
  if version_txt =~ /^(\d+)\.(\d+)\.(\d+)$/
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

  File.open(File.join(File.expand_path(File.dirname(__FILE__)), 'VERSION'), 'w') do |file|
    file.puts new_version
  end
end # def:: bump_version(level)

gemspec = Gem::Specification.new do |s|
  s.name        = GEM
  s.version     = get_version
  s.authors     = ["Algorille team"]
  s.email       = "ruby-cute-staff@lists.gforge.inria.fr"
  s.homepage    = "http://ruby-cute.gforge.inria.fr/"
  s.summary     = "Critically Useful Tools for Experiments"
  s.description = ""
  s.required_rubygems_version = ">= 1.3.6"
  s.files = ["lib/cute.rb"]
  # s.add_dependency 'some-gem'
  s.extra_rdoc_files = ['README.md','LICENSE','VERSION']
  s.license = 'CeCILL-B'
end

Gem::PackageTask.new(gemspec) do |pkg|
  pkg.gem_spec = gemspec
end

desc "Generate a gemspec file"
task :gemspec do
  File.open("#{GEM}.gemspec", "w") do |file|
    file.puts gemspec.to_ruby
  end
end
