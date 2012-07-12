/*
 * This file is part of gitg
 *
 * Copyright (C) 2012 - Jesse van den Kieboom
 *
 * gitg is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * gitg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gitg. If not, see <http://www.gnu.org/licenses/>.
 */

namespace Gitg
{

public class Window : Gtk.ApplicationWindow, GitgExt.Application, Initable, Gtk.Buildable
{
	private class ActiveUIElement
	{
		public GitgExt.UIElement element;
		public Gtk.RadioToolButton? navigation_button;

		public ActiveUIElement(GitgExt.UIElement e)
		{
			element = e;
		}
	}

	private Repository? d_repository;
	private GitgExt.MessageBus d_message_bus;
	private Peas.ExtensionSet d_extensions_view;
	private Peas.ExtensionSet d_extensions_navigation;
	private GitgExt.View? d_current_view;
	private HashTable<string, GitgExt.View> d_view_map;
	private GitgExt.ViewAction d_action;

	private HashTable<string, ActiveUIElement> d_active_elements;

	// Widgets
	private Gtk.Toolbar d_topnav;
	private Gtk.Toolbar d_subnav;
	private Gtk.Paned d_paned;
	private Gtk.Paned d_panels;
	private Gtk.Notebook d_notebook_panels;
	private GitgExt.NavigationTreeView d_navigation;
	private Gtk.Frame d_main_frame;

	public GitgExt.View? current_view
	{
		owned get { return d_current_view; }
	}

	public GitgExt.MessageBus message_bus
	{
		owned get { return d_message_bus; }
	}

	public Repository? repository
	{
		owned get { return d_repository; }
	}

	private Gtk.Toolbar toolbar_for_element(GitgExt.UIElement e)
	{
		if (e is GitgExt.View)
		{
			return d_topnav;
		}
		else
		{
			return d_subnav;
		}
	}

	private Gtk.RadioToolButton? create_nav_button(GitgExt.UIElement e)
	{
		Icon? icon = e.icon;

		if (icon == null)
		{
			return null;
		}

		var bar = toolbar_for_element(e);

		var img = new Gtk.Image.from_gicon(icon, bar.get_icon_size());
		img.show();

		Gtk.RadioToolButton button;

		if (bar.get_n_items() != 0)
		{
			var ic = bar.get_nth_item(0);
			button = new Gtk.RadioToolButton.from_widget(ic as Gtk.RadioToolButton);
		}
		else
		{
			button = new Gtk.RadioToolButton(null);
		}

		button.set_icon_widget(img);
		button.set_label(e.display_name);

		button.show();

		return button;
	}

	private void add_element(GitgExt.UIElement e)
	{
		// Add a navigation button if needed
		Gtk.RadioToolButton? button = create_nav_button(e);
		ActiveUIElement ae = new ActiveUIElement(e);

		ae.navigation_button = button;

		if (button != null)
		{
			toolbar_for_element(e).add(button);
		}

		button.toggled.connect((b) => {
			if (b.active)
			{
				// TODO: make this more scalable
				GitgExt.View ?v = e as GitgExt.View;

				if (v != null)
				{
					set_view(e);
					return;
				}

				GitgExt.Panel ?p = e as GitgExt.Panel;

				if (p != null)
				{
					set_panel(p);
				}
			}
		});

		d_active_elements.insert(e.id, ae);
	}

	private void set_panel(GitgExt.Panel p)
	{
	}

	private void update_panels()
	{
	
	}

	private void set_view(GitgExt.View v)
	{
		/* This function updates the view to @v. The following steps are
		 * involved:
		 *
		 * 1) Clear navigation tree
		 * 2) Remove all panels and panel navigation widgets
		 * 3) Remove main view widget
		 * 3) Hide panels and panel navigation
		 * 4) Set the current view to @v
		 * 5) Fill the navigation model with navigation from @v (if needed)
		 * 6) Query nagivation extensions to fill the navigation model
		 * 7) Activate available panels and corresponding buttons
		 * 8) Set current panel
		 */

		if (d_current_view == v)
		{
			return;
		}

		d_navigation.model.clear();

		// Remove panel widgets
		while (d_notebook_panels.get_n_pages() > 0)
		{
			d_notebook_panels.remove_page(0);
		}

		// Remove panel navigation buttons
		while (d_subnav.get_n_items() > 0)
		{
			d_subnav.remove(d_subnav.get_nth_item(0));
		}

		var child = d_main_frame.get_child();
		if (child != null)
		{
			d_main_frame.remove(child);
		}

		// Hide panel note book and panel navigation toolbar
		d_notebook_panels.hide();
		d_subnav.hide();

		// Deactivate the current's view button
		if (d_current_view != null)
		{
			var ae = d_active_elements.lookup(d_current_view.id);

			if (ae != null)
			{
				ae.navigation_button.set_active(false);
			}
		}

		// Set the current view
		d_current_view = v;

		// Populate navigation from the view first
		GitgExt.Navigation? nav = v.navigation;

		if (nav != null)
		{
			d_navigation.model.populate(nav);
		}

		// Populate navigation from the extensions
		d_extensions_navigation.foreach((s, info, obj) => {
			nav = obj as GitgExt.Navigation;

			if (nav.available)
			{
				d_navigation.model.populate(nav);
			}
		});

		// Expand all the navigation by default
		d_navigation.expand_all();

		// Select the first item of the navigation list
		d_navigation.select_first();

		// Set the main widget
		var widget = v.widget;

		if (widget != null)
		{
			widget.show();
			d_main_frame.add(widget);
		}

		// Set the current view's navigation button to active
		var ae = d_active_elements.lookup(v.id);

		if (ae.navigation_button != null)
		{
			ae.navigation_button.set_active(true);
		}

		update_panels();
	}

	private bool remove_ui_element(GitgExt.UIElement e)
	{
		ActiveUIElement ae;

		if (d_active_elements.lookup_extended(e.id, null, out ae))
		{
			if (ae.navigation_button != null)
			{
				ae.navigation_button.destroy();
			}

			d_active_elements.remove(e.id);
		}
	}

	private void remove_view(GitgExt.View v, bool update_current)
	{
		if (remove_ui_element(v))
		{
			d_view_map.remove(v.id);

			if (v == d_current_view)
			{
				d_current_view = null;

				if (update_current)
				{
					activate_default_view();
				}
			}
		}
	}

	private void remove_panel(GitgExt.Panel p)
	{
		remove_ui_element(p);
	}

	private void extension_view_added(Peas.ExtensionSet s,
	                                  Peas.PluginInfo info,
	                                  Object obj)
	{
		GitgExt.View v = obj as GitgExt.View;

		d_view_map.insert(v.id, v);

		if (v.is_available())
		{
			add_element(v);
		}
	}

	private void extension_view_removed(Peas.ExtensionSet s,
	                                    Peas.PluginInfo info,
	                                    Object obj)
	{
		remove_view(obj as GitgExt.View, true);
	}

	private void extension_panel_added(Peas.ExtensionSet s,
	                                   Peas.PluginInfo info,
	                                   Object obj)
	{
		GitgExt.Panel p = obj as GitgExt.Panel;

		if (p.is_available())
		{
			add_element(v);
		}
	}

	private void extension_panel_removed(Peas.ExtensionSet s,
	                                     Peas.PluginInfo info,
	                                     Object obj)
	{
		remove_panel(obj as GitgExt.Panel);
	}

	private void update_nav_visibility(Gtk.Toolbar tb)
	{
		tb.visible = (tb.get_n_items() > 1);
	}

	private void parser_finished(Gtk.Builder builder)
	{
		d_topnav = builder.get_object("toolbar_topnav") as Gtk.Toolbar;
		d_subnav = builder.get_object("toolbar_subnav") as Gtk.Toolbar;
		d_paned = builder.get_object("paned_main") as Gtk.Paned;
		d_panels = builder.get_object("paned_panel") as Gtk.Paned;
		d_main_frame = builder.get_object("frame_main") as Gtk.Frame;

		d_navigation = builder.get_object("tree_view_navigation") as GitgExt.NavigationTreeView;
		d_notebook_panels = builder.get_object("notebook_panels") as Gtk.Notebook;

		d_topnav.add.connect((t, widget) => {
			update_nav_visibility(d_topnav);
		});

		d_topnav.remove.connect((t, widget) => {
			update_nav_visibility(d_topnav);
		});

		d_subnav.add.connect((t, widget) => {
			update_nav_visibility(d_subnav);
		});

		d_subnav.remove.connect((t, widget) => {
			update_nav_visibility(d_subnav);
		});

		base.parser_finished(builder);
	}

	private bool init(Cancellable? cancellable)
	{
		// Setup message bus
		d_message_bus = new GitgExt.MessageBus();

		// Initialize peas extensions set for views
		var engine = PluginsEngine.get_default();

		d_extensions_view = new Peas.ExtensionSet(engine,
		                                          typeof(GitgExt.View),
		                                          "application",
		                                          this);

		d_extensions_navigation = new Peas.ExtensionSet(engine,
		                                                typeof(GitgExt.Navigation),
		                                                "application",
		                                                this);

		d_extensions_panels = new Peas.ExtensionSet(engine,
		                                            typeof(GitgExt.Panel),
		                                            "application",
		                                            this);

		d_view_map = new HashTable<string, GitgExt.View>(str_hash, str_equal);
		d_active_elements = new HashTable<string, ActiveUIElement>(str_hash, str_equal);

		// Add all the extensions
		d_extensions_view.foreach(extension_view_added);
		d_extensions_view.extension_added.connect(extension_view_added);
		d_extensions_view.extension_removed.connect(extension_view_removed);

		d_extensions_panel.foreach(extension_panel_added);
		d_extensions_panel.extension_added.connect(extension_panel_added);
		d_extensions_panel.extension_removed.connect(extension_panel_removed);

		activate_default_view();

		return true;
	}

	public static Window? create_new(Gtk.Application app,
	                                 Repository? repository,
	                                 GitgExt.ViewAction action)
	{
		Window? ret = Resource.load_object<Window>("ui/gitg-window.ui", "window");

		if (ret != null)
		{
			ret.d_repository = repository;
			ret.d_action = action;
		}

		try
		{
			((Initable)ret).init(null);
		} catch {}

		return ret;
	}

	private void activate_default_view()
	{
		GitgExt.View? def = null;

		// Activate the default view
		d_extensions_view.foreach((s, info, obj) => {
			GitgExt.View v = obj as GitgExt.View;

			if (d_active_views.lookup_extended(v.id, null, null))
			{
				if (v.is_default_for(d_action))
				{
					set_view(v);
					def = null;
					return;
				}
				else if (def == null)
				{
					def = v;
				}
			}
		});

		if (def != null)
		{
			set_view(def);
		}
	}

	private void update_views()
	{
		/* This method is called after some state has changed and thus a new
		 * set of views needs to be computed. Currently the only state change
		 * is opening or closing a repository.
		 */

		// Now see if new views became available
		d_extensions_view.foreach((s, info, obj) => {
			GitgExt.View v = obj as GitgExt.View;

			bool isavail = v.is_available();
			bool isactive = d_active_views.lookup_extended(v.id, null, null);

			if (isavail == isactive)
			{
				return;
			}

			if (isactive)
			{
				// should be inactive
				remove_view(v, false);
			}
			else
			{
				add_element(v);
			}
		});

		activate_default_view();
	}

	/* public API implementation of GitgExt.Application */
	public GitgExt.View? view(string id)
	{
		GitgExt.View v;

		if (d_view_map.lookup_extended(id, null, out v))
		{
			set_view(v);
		}

		return null;
	}

	public void open(File path)
	{
		File repo;

		if (d_repository != null &&
		    d_repository.get_location().equal(path))
		{
			return;
		}

		try
		{
			repo = Ggit.Repository.discover(path);
		}
		catch
		{
			// TODO
			return;
		}

		if (d_repository != null)
		{
			close();
		}

		try
		{
			d_repository = new Gitg.Repository(repo, null);
		}
		catch {}

		update_views();
	}

	public void create(File path)
	{
		// TODO
	}

	public void close()
	{
		// TODO
	}
}

}

// ex:ts=4 noet
