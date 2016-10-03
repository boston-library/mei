class MeiMultiLookupInput < MultiValueInput
  # Overriding this so that the class is correct and the javascript for multivalue will work on this.
  def input_type
    'multi_value'.freeze
  end

  def inner_wrapper
    <<-HTML
          <li class="field-wrapper">
<div class="input-group col-sm-12">
            #{yield}
             <button style="width:auto;" type="button" class="btn btn-default" data-toggle="modal" data-target="#meiLookupModal_#{attribute_name}">Lookup</button>
</div>
          </li>
    HTML
  end

  # Although the 'index' parameter is not used in this implementation it is useful in an
  # an overridden version of this method, especially when the field is a complex object and
  # the override defines nested fields.
  def build_field_options(value, index)
    options = input_html_options.dup

    options[:value] = value
    if @rendered_first_element
      options[:id] = nil
      options[:required] = nil
    else
      options[:id] ||= input_dom_id
    end
    options[:class] ||= []
    options[:class] += ["#{input_dom_id} form-control multi-text-field"]
    options[:style] ||= []
    options[:style] += ["width:80%"]
    options[:'aria-labelledby'] = label_id
    @rendered_first_element = true

    options
  end

=begin
  def inner_wrapper
    <<-HTML
          <li class="field-wrapper">
             <div class="input-group col-sm-12">
              #{yield}

             <button style="width:auto;" type="button" class="btn btn-default" data-toggle="modal" data-target="#meiLookupModal_#{attribute_name}">Lookup</button>
              <span class="input-group-btn regular_dta_duplicate_span">
                <button class="btn btn-success regular_dta_duplicate_field" type="button">+</button>
              </span>
                    <span class="input-group-btn regular_dta_delete_span">
                      <button class="btn btn-danger regular_dta_delete_field" type="button">-</button>
                    </span>
              </div>
          </li>
    HTML
  end
=end
end