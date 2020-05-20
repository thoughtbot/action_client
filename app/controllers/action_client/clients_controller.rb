module ActionClient
  class ClientsController < ActionClient::ApplicationController
    def index
      render locals: {
        clients: ActionClient::Preview.all,
      }
    end

    def show
      preview = ActionClient::Preview.find(params[:id])

      if preview.present?
        render locals: {
          client: preview,
        }
      else
        raise AbstractController::ActionNotFound
      end
    end
  end
end
