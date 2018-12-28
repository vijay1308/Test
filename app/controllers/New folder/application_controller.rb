# Get user in models if available
module Current
  thread_mattr_accessor :user
end

class ApplicationController < ActionController::API
  include AbstractController::Translation

  before_action :authenticate_user_from_token!
  before_action :set_paper_trail_whodunnit
  around_action :set_current_user
  #rescue_from Exception, :with => :handle_exception
  respond_to :json

  def set_current_user
    Current.user = @user
    yield
  ensure
    # to address the thread variable leak issues in Puma/Thin webserver
    Current.user = nil
  end


  ##
  # User Authentication
  # Authenticates the user with OAuth2 Resource Owner Password Credentials Grant
  def authenticate_user_from_token!
    auth_token = request.headers['Authorization']

    if auth_token
      authenticate_with_auth_token auth_token
    else
      authentication_error
    end
  end

  def handle_exception(exception)
    if exception.is_a?(ActiveRecord::InvalidForeignKey)
      render json: {message: "This record is associated with other records it cannot be delete"}, status: :unprocessable_entity
      #render json: {message: exception.to_s}
    else
      render json: {message: exception}, status: :unprocessable_entity
    end
  end

  #will used with cancan
  # rescue_from CanCan::AccessDenied do |exception|
  #   respond_to do |format|
  #     format.json { head :forbidden, content_type: 'text/html' }
  #     format.html { redirect_to main_app.root_url, notice: exception.message }
  #     format.js   { head :forbidden, content_type: 'text/html' }
  #   end
  # end

  private

  def authenticate_with_auth_token auth_token
    unless auth_token.include?(':')
      authentication_error
      return
    end

    user_id = auth_token.split(':').first
    @user = User.where(id: user_id).first

    if @user && Devise.secure_compare(@user.access_token, auth_token)
      # User can access
      sign_in @user, store: false
    else
      authentication_error
    end
  end

  ##
  # Authentication Failure
  # Renders a 401 error
  def authentication_error
    # User's token is either invalid or not in the right format
    #render json: {error: t('application_controller.unauthorized')}, status: 401  # Authentication timeout
    render json: {message: "Invalid authentication token"}, status: 401  # Authentication timeout
  end

  # get user information for versions
  def user_for_paper_trail
    @user ? @user.id : 'No user'  # or whatever
  end

end

