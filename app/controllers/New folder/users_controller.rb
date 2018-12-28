module V1
  class UsersController < ApplicationController
    skip_before_action :authenticate_user_from_token!, only: [:create]

    #get/v1/users
    def index
      @users = User.includes(:profile, :role).all.order('profiles.first_name ASC')
      render json: @users, each_serializer: UserSerializer, root: "users", adapter: :json
    end

    def show
      @user = User.find(params[:id])
      render json: @user, serializer: V1::UserSerializer, root: "user", adapter: :json
    end

    # POST /v1/users
    # Creates an user
    def create
      params[:user][:password] = SecureRandom.hex(4)
      params[:user][:password_confirmation] = params[:user][:password]
      @user = User.new(user_params)
      if @user.save
        @user.profile.update_attributes(profile_params) unless profile_params.blank?
        UserMailer.send_user_password(@user, params).deliver_now
        render json: @user, serializer: V1::UserSerializer, root: "user", adapter: :json
      else
        render json: @user.error_messages, status: :unprocessable_entity
      end
    end

    def destroy
      user = User.find(params[:id])
      if user
        user.destroy
        head :no_content
      else
        head :not_found
      end

    end

    def update
      @user = User.find(params[:id])
      #@user.user_roles.destroy_all if @user.user_roles.present?
      if @user && @user.update_attributes(update_params)
        @user.create_user_profile unless @user.profile.present?
        @user.profile.update_attributes(profile_params) unless profile_params.blank?
        render json: @user, serializer: V1::UserSerializer, root: "user", adapter: :json
      else
        render json: @user.try(:error_messages), status: :unprocessable_entity
      end
    end

    def update_password
      if @user.valid_password?(params[:current_password])
        if @user.update(password_params)
          render json: {message: "Password change succefully"}, status: :ok
        else
          render json: @user.error_messages, status: :unprocessable_entity
        end
      else
        render json: {message: "current password not matched"}, status: :unprocessable_entity
      end
    end

    def export
      unexpected_column_names = ["encrypted_password", "reset_password_token", "reset_password_sent_at", "remember_created_at", "sign_in_count", "current_sign_in_at", "last_sign_in_at", "current_sign_in_ip", "last_sign_in_ip", "access_token"]
      render json: {path: User.to_csv(@user.id, [], unexpected_column_names)}, status: :ok
    end

    def list_of_methods
      render json: {"controllers": User::SETTINGS.sort, "permissions": User::POSSIBLE_PERMISSIONS}
    end

    private

    def update_params
      params.require(:user).permit(:superuser, :role_id).merge(permissions: allow_params)
      # uparams = params.require(:user).permit(:superuser,
      #     {user_roles: [:id, :role_id, :_destroy]}
      #    )
      # if uparams[:superuser].to_bool
      #   uparams.delete :user_roles if uparams[:user_roles]
      # end
      # uparams[:user_roles_attributes] = uparams.delete :user_roles if uparams[:user_roles]
      # uparams.permit!
    end

    def user_params
      params.require(:user).permit(:email, :password, :password_confirmation, :superuser, :role_id).merge(permissions: allow_params)

      # uparams = params.require(:user).permit(:email, :password, :password_confirmation, :superuser,
      #     {user_roles: [:id, :role_id, :_destroy]}
      #    )
      # if uparams[:superuser].to_bool
      #   uparams.delete :user_roles if uparams[:user_roles]
      # end
      # uparams[:user_roles_attributes] = uparams.delete :user_roles if uparams[:user_roles]
      # uparams.permit!
    end

    def profile_params
      params.require(:user).permit(:first_name, :last_name, :address, :gender, :phone_number, :user_id, :title)
    end

    def password_params
      params.permit(:password, :password_confirmation, :current_password)
    end

    def allow_params
    permissions_params = {}
    begin
      params[:user][:permissions].each do |key, values|
        permissions_params[key] = values
      end
    rescue Exception => e
      return nil
    end
    permissions_params
  end

  end
end

