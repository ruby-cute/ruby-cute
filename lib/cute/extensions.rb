# Extends the class string for supporting timespan formats
class String

  def to_secs

    return Infinity if [ 'always', 'forever', 'infinitely' ].include?(self.to_s)
    parts = self.split(':').map { |x| x.to_i rescue nil }
    if parts.all? && [ 2, 3 ].include?(parts.length)
      secs = parts.zip([ 3600, 60, 1 ]).map { |x, y| x * y }.reduce(:+)
      return secs
    end
    m = /^(\d+|\d+\.\d*)\s*(\w*)?$/.match(self)
    num, unit = m.captures
    mul = case unit
          when '' then 1
          when 's' then 1
          when 'm' then 60
          when 'h' then 60 * 60
          when 'd' then 24 * 60 * 60
          else nil
          end
    raise "Unknown timespan unit: '#{unit}' in #{self}" if mul.nil?
    return num.to_f * mul
  end

  def to_time
    secs = self.to_secs.to_i
    minutes = secs / 60; secs %= 60
    hours = minutes / 60; minutes %= 60
    minutes += 1 if secs > 0
    return '%.02d:%.02d' % [ hours, minutes ]
  end

  def is_i?
    /\A[-+]?\d+\z/ === self
  end

end
