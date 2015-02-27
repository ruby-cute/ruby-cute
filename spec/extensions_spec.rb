require 'spec_helper'


describe "Monkey patch to class String" do

  it "converts walltime format into seconds" do
    digits = []

    (0..9).each{ |x| digits.push(x.to_s)}
    time = digits.combination(2).to_a.map{ |x| x.join("")}.select{ |h| h.to_i < 60 }
    walltime = time.combination(3).to_a.map{ |x| x.join(":")}

    expect {walltime.each{ |t| t.to_secs}}.not_to raise_error
  end


end
