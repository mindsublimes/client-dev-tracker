module ApplicationHelper
  def flash_class_for(type)
    case type.to_sym
    when :notice, :success
      'alert-success'
    when :alert, :error
      'alert-danger'
    when :warning
      'alert-warning'
    else
      'alert-info'
    end
  end

  def nav_link_class(path)
    classes = ['nav-link']
    classes << 'active fw-semibold' if current_page?(path)
    classes.join(' ')
  end

  def calendar_filter_params(filters)
    # Convert symbol keys to string keys and remove nil values for URL parameters
    filters.to_h.transform_keys(&:to_s).compact
  end
end
