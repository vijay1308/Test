class V1::RolesController < ApplicationController
  before_action :set_role, only: [:show, :update, :destroy]

  # GET /roles
  def index
    render json: Role.all, each_serializer: V1::RoleSerializer, root: "roles"
  end

  # GET /roles/1
  def show
    render json: @role, serializer: V1::RoleSerializer
  end

  # POST /roles
  def create
    @role = Role.new(role_params)
    if @role.save
      render json: @role, status: :created, location: v1_role_path(@role), root: "role", adapter: :json
    else
      render json: @role.error_messages, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /roles/1
  def update
    if @role.update(role_params)
      render json: @role
    else
      render json: @role.error_messages, status: :unprocessable_entity
    end
  end

  # DELETE /roles/1
  def destroy
    if @role.destroy
      head :no_content
    else
      render json: @role.error_messages, status: :unprocessable_entity
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_role
    @role = Role.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def role_params
    params.require(:role).permit(:role_name, :role_description).merge(role_permissions: allow_params)
  end

  def allow_params
    role_permission_params = {}
    begin
      params[:role][:role_permissions].each do |key, values|
        role_permission_params[key] = values
      end
    rescue Exception => e
      return nil
    end
    role_permission_params
  end
end
