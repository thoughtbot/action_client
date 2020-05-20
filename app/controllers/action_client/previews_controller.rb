module ActionClient
  class PreviewsController < ActionClient::ApplicationController
    def show
      client = ActionClient::Preview.find(params[:client_id])
      action_name = params[:id]

      if client.present? && client.exists?(action_name)
        preview = client.new(action_name: action_name)

        render locals: {
          client: client,
          preview: preview,
        }
      else
        raise AbstractController::ActionNotFound
      end
    end
  end
end
