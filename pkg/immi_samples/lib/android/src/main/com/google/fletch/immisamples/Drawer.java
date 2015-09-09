// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.immisamples;

import android.app.Fragment;
import android.os.Handler;
import android.os.Looper;
import android.support.v4.widget.DrawerLayout;

import immi.AnyNode;
import immi.AnyNodePatch;
import immi.AnyNodePresenter;
import immi.DrawerNode;
import immi.DrawerPatch;
import immi.DrawerPresenter;
import immi.EmptyPaneNode;
import immi.EmptyPanePatch;

public class Drawer implements DrawerPresenter {

  /**
   * Abstract base class for a fragment implementing a drawer pane.
   */
  public static abstract class PaneFragment extends Fragment {
    /**
     * Implementors of a drawer-pane fragment must use this to associate actions with its presenter.
     * @param layout Drawer layout containing this fragment.
     * @param presenter Pane presenter associated with this fragment.
     */
    public abstract void setup(DrawerLayout layout, PanePresenter presenter);

    /**
     * Implementors must define this such that it will adjust the state of the drawer pane.
     * @param open Requested 'open' state value to set the panes view to.
     */
    public abstract void setOpenedState(boolean open);
  }

  /**
   * Abstract base class for a presenter that is used in a drawer pane.
   */
  public static abstract class PanePresenter implements AnyNodePresenter {
    /**
     * Accessor for the drawer-pane fragment associated with this presenter.
     */
    public abstract PaneFragment getPaneFragment();

    /**
     * Toggle the presentation state of this drawer pane.
     */
    public final void toggle() { proxy.toggle(); }

    /**
     * Set the presentation state to 'open' on this drawer pane.
     */
    public final void open() { proxy.open(); }

    /**
     * Set the presentation state to 'closed' on this drawer pane.
     */
    public final void close() { proxy.close(); }

    private void setup(DrawerLayout layout, DrawerProxy proxy) {
      this.proxy = proxy;
      getPaneFragment().setup(layout, this);
    }

    private DrawerProxy proxy;
  }

  public Drawer(DrawerLayout layout,
                PanePresenter left,
                AnyNodePresenter center,
                PanePresenter right) {
    centerPresenter = center;
    leftPresenter = left;
    rightPresenter = right;
    if (left != null) {
      left.setup(layout, new DrawerProxy() {
        @Override public void toggle() { toggleLeft(); }
        @Override public void open() { setLeftVisible(true); }
        @Override public void close() { setLeftVisible(false); }
      });
    }
    if (right != null) {
      right.setup(layout, new DrawerProxy() {
        @Override public void toggle() { toggleRight(); }
        @Override public void open() { setRightVisible(true); }
        @Override public void close() { setRightVisible(false); }
      });
    }
  }

  public boolean isReady() { return root != null; }

  public boolean getLeftVisible() {
    return root.getLeftVisible();
  }

  public boolean getRightVisible() {
    return root.getRightVisible();
  }

  public void setLeftVisible(boolean leftVisible) {
    if (getLeftVisible() != leftVisible) toggleLeft();
  }

  public void setRightVisible(boolean rightVisible) {
    if (getRightVisible() != rightVisible) toggleRight();
  }

  public void toggleLeft() {
    root.getToggleLeft().dispatch();
  }

  public void toggleRight() {
    root.getToggleRight().dispatch();
  }

  @Override
  public void present(final DrawerNode node) {
    root = node;
    presentPane(node.getLeft(), leftPresenter);
    if (centerPresenter != null) centerPresenter.present(node.getCenter());
    presentPane(node.getRight(), rightPresenter);
    new Handler(Looper.getMainLooper()).post(new Runnable() {
      @Override
      public void run() {
        setPaneOpenedState(node.getLeftVisible(), leftPresenter);
        setPaneOpenedState(node.getRightVisible(), rightPresenter);
        }
    });
  }

  @Override
  public void patch(final DrawerPatch patch) {
    root = patch.getCurrent();
    patchPane(patch.getLeft(), leftPresenter);
    if (centerPresenter != null) patch.getCenter().applyTo(centerPresenter);
    patch.getRight().applyTo(rightPresenter);
    if (patch.getLeftVisible().hasChanged() || patch.getRightVisible().hasChanged()) {
      new Handler(Looper.getMainLooper()).post(new Runnable() {
        @Override
        public void run() {
          if (patch.getLeftVisible().hasChanged()) {
            setPaneOpenedState(patch.getLeftVisible().getCurrent(), leftPresenter);
          }
          if (patch.getRightVisible().hasChanged()) {
            setPaneOpenedState(patch.getRightVisible().getCurrent(), rightPresenter);
          }
        }
      });
    }
  }

  private interface DrawerProxy {
    void toggle();
    void open();
    void close();
  }

  private void presentPane(AnyNode node, PanePresenter presenter) {
    if (presenter != null && !node.is(EmptyPaneNode.class)) presenter.present(node);
  }

  private void patchPane(AnyNodePatch patch, PanePresenter presenter) {
    if (presenter != null && !patch.is(EmptyPanePatch.class)) patch.applyTo(presenter);
  }

  private void setPaneOpenedState(boolean open, PanePresenter presenter) {
    if (presenter != null) presenter.getPaneFragment().setOpenedState(open);
  }

  private DrawerNode root;
  private AnyNodePresenter centerPresenter;
  private PanePresenter leftPresenter;
  private PanePresenter rightPresenter;
}
