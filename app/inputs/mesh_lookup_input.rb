class MeshLookupInput < MeiMultiLookupInput
  #include WithHelpIcon

  def buffer_each(collection)
    collection.each_with_object('').with_index do |(value, buffer), index|
      if  value.blank? and !@rendered_first_element
        buffer << yield(value, index)
      elsif value.match(/http:\/\/id.nlm.nih.gov\/mesh\//)
        value_label = value
        repo = Mei::Mesh.pop_graph(value)
        repo.query(:subject=>::RDF::URI.new(value), :predicate=>Mei::Mesh.rdfs_namepace('label')).each_statement do |result_statement|
          value_label = result_statement.object.value
        end
        buffer << yield("#{value_label} (#{value})", index)
      end
    end
  end

  def collection
    @collection ||= Array.wrap(object.send(attribute_name)).reject { |value| value.to_s.strip.blank? } + ['']
   # @collection ||= Array.wrap(object[attribute_name]).reject { |value| value.to_s.strip.blank? } + ['']
  end

end