module RecordSelect
  module Conditions
    protected
    # returns the combination of all conditions.
    # conditions come from:
    # * current search (params[:search])
    # * intelligent url params (e.g. params[:first_name] if first_name is a model column)
    # * specific conditions supplied by the developer
    def record_select_conditions
      conditions = []

      merge_conditions(
        record_select_conditions_from_search,
        record_select_conditions_from_params,
        record_select_conditions_from_controller
      )
    end

    # an override method.
    # here you can provide custom conditions to define the selectable records. useful for situational restrictions.
    def record_select_conditions_from_controller; end

    # another override method.
    # define any association includes you want for the finder search.
    def record_select_includes; end

    def record_select_like_operator
      @like_operator ||= ::ActiveRecord::Base.connection.adapter_name == "PostgreSQL" ? "ILIKE" : "LIKE"
    end

    # define special list of selected fields,
    # mainly to define extra fields that can be used for 
    # specialized sorting.
    def record_select_select
    end

    # generate conditions from params[:search]
    # override this if you want to customize the search routine
    def record_select_conditions_from_search
      if params[:search] && !params[:search].strip.empty?
        if record_select_config.full_text_search?
          tokens = params[:search].strip.split(' ')
        else
          tokens = [params[:search].strip]
        end
        search_pattern = record_select_config.full_text_search? ? '%?%' : '?%'
        build_record_select_conditions(tokens, record_select_like_operator, search_pattern)
      end
    end
    
    def build_record_select_conditions(tokens, operator, search_pattern)
      where_clauses = record_select_config.search_on.collect { |sql| "#{sql} #{operator} ?" }
      phrase = "(#{where_clauses.join(' OR ')})"
      sql = ([phrase] * tokens.length).join(' AND ')
      
      tokens = tokens.collect { |token| [search_pattern.sub('?', token)] * record_select_config.search_on.length }.flatten
      [sql, *tokens]
    end

    # generate conditions from the url parameters (e.g. users/browse?group_id=5)
    def record_select_conditions_from_params
      conditions = nil
      params.each do |field, value|
        next unless column = record_select_config.model.columns_hash[field]
        conditions = merge_conditions(
          conditions,
          record_select_condition_for_column(column, value)
        )
      end
      conditions
    end

    @@type_cast_method = Rails.version < '4.2' ? :type_cast : :type_cast_from_user
    # generates an SQL condition for the given column/value
    def record_select_condition_for_column(column, value)
      model = record_select_config.model
      column_name = model.quoted_table_name + '.' + model.connection.quote_column_name(column.name)
      if value.blank? and column.null
        "#{column_name} IS NULL"
      elsif column.text?
        ["LOWER(#{column_name}) LIKE ?", value]
      else
        ["#{column_name} = ?", column.send(@@type_cast_method, value)]
      end
    end

    def merge_conditions(*conditions) #:nodoc:
      c = conditions.find_all {|c| not c.nil? and not c.empty? }
      c.empty? ? nil : c.collect{|c| record_select_config.model.send(:sanitize_sql, c)}.join(' AND ')
    end
  end
end
