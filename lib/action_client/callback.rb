module ActionClient
  class Callback
    def self.call(context, response, method_name_or_callback)
      callback = if method_name_or_callback.is_a?(Symbol)
        context.method(method_name_or_callback)
      else
        method_name_or_callback
      end

      if callback.arity == 1
        context.instance_exec(response.body, &callback)
      elsif callback.arity == 3
        context.instance_exec(*response.to_a, &callback)
      else
        context.instance_exec(&callback)
      end
    end
  end
end
