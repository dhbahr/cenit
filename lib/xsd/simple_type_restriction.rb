module Xsd
  class SimpleTypeRestriction < BasicTag

    tag 'xs:restriction'

    attr_reader :base
    attr_reader :restrictions

    def initialize(parent, base, restrictions=nil)
      super(parent)
      @base = base
      @restrictions = {}
      restrictions.each { |key, value| @restrictions[key] = value } if restrictions
    end

    def start_element(name, attributes)
      unless %w{xs:annotation xs:documentation}.include?(name)
        if name == 'xs:enumeration'
          @restrictions[name] ||= []
          @restrictions[name] << attributes
        else
          @restrictions[name] = attributes
        end
      end
      nil
    end

    def to_json_schema
      json = base.to_json_schema
      @restrictions.each do |key, value|
        restriction = case key
                        when 'xs:enumeration'
                          {'enum' => value.collect { |v| v[0][1] }}
                        when 'xs:length'
                          {'minLength' => value[0][1].to_i, 'maxLength' => value[0][1].to_i}
                        when 'xs:pattern'
                          {'pattern' => value[0][1]}
                        when 'xs:minInclusive'
                          {'minimum' => value[0][1].to_i}
                        when 'xs:maxInclusive'
                          {'maximum' => value[0][1].to_i}
                        when 'xs:minExclusive'
                          {'minimum' => value[0][1].to_i, 'exclusiveMinimum' => true}
                        when 'xs:maxExclusive'
                          {'maximum' => value[0][1].to_i, 'exclusiveMaximum' => true}
                        else
                          {(key = key.gsub('xs:', '')) => value[0][1].to_i}
                      end

        json = json.merge(restriction)
      end
      return json
    end

  end
end