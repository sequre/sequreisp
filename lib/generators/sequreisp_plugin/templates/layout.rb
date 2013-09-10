<% content_for :sequreisp_plugin_menu do %>
  <% content_for :plugin_name, t("plugin.name") %>
  <% content_for :plugin_menu do %>
    <ul class="nav plugin_menu">
        <li> <a class="no_pointer" href="javascript:void(null)"> "menu1" </a>
          <ul class="submenu">
            <li></li>
            <li></li>
          </ul>
        </li>
        <li> <a class="no_pointer" href="javascript:void(null)"> "menu2" </a>
          <ul class="submenu">
            <li></li>
            <li></li>
          </ul>
        </li>
    </ul>
  <% end %>
  <%= render :partial => 'layouts/partials/plugin_submenu' %>
<% end %>
<%= render :file => 'layouts/application' %>
