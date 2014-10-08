require_dependency "para/application_controller"

module Para
  module Admin
    class ResourcesController < Para::Admin::BaseController
      class_attribute :resource_name, :resource_class

      load_and_authorize_resource :component, class: 'Para::Component::Base',
                                  find_by: :slug

      helper_method :resource

      def new
        render 'para/admin/resources/new'
      end

      def create
        resource.component = @component

        if resource.save
          flash_message(:success, resource)
          redirect_to component_path(@component)
        else
          flash_message(:error, resource)
          render 'new'
        end
      end

      def edit
        render 'para/admin/resources/edit'
      end

      def update
        if resource.update_attributes(resource_params)
          flash_message(:success, resource)
          redirect_to component_path(@component)
        else
          flash_message(:error, resource)
          render 'edit'
        end
      end

      def destroy
        resource.destroy
        flash_message(:success, resource)
        redirect_to component_path(@component)
      end

      def order
        resources_params = params[:resources].values

        ids = resources_params.map { |resource| resource[:id] }

        resources = resource_model.where(id: ids)
        resources_hash = resources.each_with_object({}) do |resource, hash|
          hash[resource.id.to_s] = resource
        end

        ActiveRecord::Base.transaction do
          resources_params.each do |resource_params|
            resource = resources_hash[resource_params[:id]]
            resource.position = resource_params[:position].to_i
            resource.save(validate: false)
          end
        end

        head 200
      end

      private

      def self.resource(name, options = {})
        default_options = {
          class: name.to_s.camelize,
          through: :component,
          parent: false
        }

        default_options.each do |key, value|
          options[key] = value unless options.key?(key)
        end

        self.resource_name = name
        self.resource_class = options[:class]

        load_and_authorize_resource(name, options)
      end

      def resource_model
        @resource_model ||= begin
          ensure_resource_name_defined!
          Para.const_get(self.class.resource_class)
        end
      end

      def resource
        @resource ||= begin
          ensure_resource_name_defined!
          instance_variable_get(:"@#{ self.class.resource_name }")
        end
      end

      def resource_params
        @resource_params ||= params.require(:resource).permit!
      end

      def ensure_resource_name_defined!
        unless self.class.resource_name
          raise "Resource not defined in your controller. " \
                "You can define the resource of your controller with the " \
                "`resource :resource_name` macro when subclassing " \
                "Para::Admin::ResourcesController"
        end
      end
    end
  end
end
