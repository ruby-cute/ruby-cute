require 'spec_helper'

describe Cute::TakTuk::Stream do

  subject { Cute::TakTuk::Stream.new([:output, :error, :status ]) }

  def random_string(length)
    valid_chars = []
    (32..126).each{ |x| valid_chars.push(x.chr)}
    (1..length).map{ valid_chars[rand(valid_chars.length-1)]}.join
  end

  it "creates an stream" do
    stream = Cute::TakTuk::Stream.new
    expect(stream.types.empty?).to be true
  end

  it "checking types" do
    stream = Cute::TakTuk::Stream.new([:output, :error, :status ])
    expect(stream.types.length).to be 3
  end

  it "returns empty result" do
    string = random_string(50)
    expect(subject.parse(string).empty?).to be true
  end

  it "returns empty value" do
    string ="machine.fr/output/aaaaaaaaaa"
    result = subject.parse(string)
    expect(result.values.first[:output].length).to be 0
  end

  it "parses simple string" do
    value = random_string(50)
    string ="machine.fr/output/123:#{value}\n"
    expect(subject.parse(string).empty?).to be false
  end

  it "parses string with number" do
    string = "machine/output/1:1\n"
    expect(subject.parse(string).empty?).to be false
  end

  it "parses the same line twice" do
    string = "machine/output/1:1\n output/machine/1:2\n"
    expect(subject.parse(string).empty?).to be false
  end

  it "has just one key" do
    string = "machine/output/1:1\n"
    expect(subject.parse(string).keys.length).to be 1
  end

  it "has two keys" do
    string = "machine1/output/1:1\nmachine2/output/1:2\n"
    expect(subject.parse(string).keys.length).to be 2
  end

  it "returns the same output" do
    value = random_string(100)
    stdout = "1:"+value
    string = "machine.fr/output/#{stdout}"
    result = subject.parse(string)
    expect(result.values.first[:output]).to eq(value)
  end

  it "parses very long output" do
    value = random_string(1000)
    stdout = "1:"+value
    string = "machine.fr/output/#{stdout}"
    result = subject.parse(string)
    expect(result.values.first[:output]).to eq(value)
  end

  it "parses hostname and ip" do
    value = random_string(1000)
    stdout = "1:"+value
    machines =["machine.fr","192.168.101.56"]
    string = "#{machines[0]}/output/#{stdout} \n#{machines[1]}/output/#{stdout}"
    result = subject.parse(string)
    expect(result.keys).to eq(machines)
  end

  it "concatenates stdouts" do
    value = random_string(100)
    stdout = "1:"+value # by default streams are formated /machine_name/stream/something:output
                        # the "something:" it is just for making the execution time of the regex shorter.
    string = "machine.fr/output/#{stdout}\nmachine.fr/output/#{stdout}\n"
    expect(subject.parse(string).values.first[:output].length).to be 2*value.length + 1
  end

end

describe "TakTuk" do
  it "raises an argument error" do
    expect{Cute::TakTuk::TakTuk.new()}.to raise_error(ArgumentError)
  end

  it "raises an argument error" do
    expect{Cute::TakTuk::TakTuk.new("aaa","aaa")}.to raise_error(ArgumentError)
  end

  it "does not raise error" do
    # TakTuk validate options at the beginning of the execution.
    expect{Cute::TakTuk::TakTuk.new("aaa",{:aaa => "aaa"})}.not_to raise_error
  end

  it "raises an argu" do
    tak = Cute::TakTuk::TakTuk.new("aaa",{:aaa => "aaa"})
    expect{ tak.exec!("haha")}.to raise_error(ArgumentError)
  end

  it "raises error due to a non existing file " do
    tak = Cute::TakTuk::TakTuk.new("aaa",{:user => "aaa"})
    expect{ tak.exec!("haha")}.to raise_error
  end

  it "raises er" do
    tak = Cute::TakTuk::TakTuk.new(["aaa"],{:user => "aaa"})
    expect{ tak.exec!("haha")}.not_to raise_error
  end

  it "raises er" do
    tak = Cute::TakTuk::TakTuk.new(["aaa"],{:user => "aaa", :config => "conf_ssh_vagrant"})
    expect{ tak.exec!("haha")}.not_to raise_error
  end

end
