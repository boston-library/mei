module Mei
  class MeshSubjectResource

    def self.find(subject, type, solr_field)
      authority_check = Mei::Mesh.new(type, solr_field)
      authority_result = authority_check.search(subject) #URI escaping doesn't work for Baseball fields?
      if authority_result.present?
        return authority_result
      else
        return []
      end
    end
  end
end