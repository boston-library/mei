module Mei
  class Helper
    def self.strip_uri(s)
      left_paran = s.rindex(/\(/)
      right_paran = s.rindex(/\)/)
      s[left_paran+1..right_paran-1]
    end
  end
end
