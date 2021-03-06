/*
 * gitg-dnd.h
 * This file is part of gitg - git repository viewer
 *
 * Copyright (C) 2009 - Jesse van den Kieboom
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, 
 * Boston, MA 02111-1307, USA.
 */

#ifndef __GITG_DND_H__
#define __GITG_DND_H__

#include <gtk/gtk.h>
#include <libgitg/gitg-ref.h>
#include <libgitg/gitg-revision.h>

G_BEGIN_DECLS

typedef gboolean (*GitgDndCallback)(GitgRef *source, GitgRef *dest, gboolean dropped, gpointer callback_data);
typedef gboolean (*GitgDndRevisionCallback)(GitgRevision *source, GitgRef *dest, gboolean dropped, gpointer callback_data);

void gitg_dnd_enable (GtkTreeView *tree_view,
                      GitgDndCallback callback,
                      GitgDndRevisionCallback revision_callback,
                      gpointer callback_data);

void gitg_dnd_disable (GtkTreeView *tree_view);

G_END_DECLS

#endif /* __GITG_DND_H__ */

