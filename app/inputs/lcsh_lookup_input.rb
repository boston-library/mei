class LcshLookupInput < MeiMultiLookupInput
  include WithHelpIcon

  def buffer_each(collection)
    collection.each_with_object('').with_index do |(value, buffer), index|
      buffer << yield(value, index) if value.match(/http:\/\/id.loc.gov\/authorities\/subjects\//) || value.blank?
    end
  end

end