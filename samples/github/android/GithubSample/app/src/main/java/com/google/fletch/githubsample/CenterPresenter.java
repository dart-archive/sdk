// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.app.Activity;
import android.app.Fragment;
import android.app.FragmentManager;
import android.app.FragmentTransaction;
import android.content.pm.ActivityInfo;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.BitmapShader;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Shader;
import android.os.Bundle;
import android.support.v7.widget.RecyclerView;
import android.transition.Slide;
import android.view.View;

import com.google.fletch.immisamples.SlidingWindow;

import immi.AnyNode;
import immi.AnyNodePatch;
import immi.AnyNodePresenter;
import immi.CommitPatch;
import immi.ListPatch;
import immi.NodePatch;
import immi.SlidingWindowNode;
import immi.SlidingWindowPatch;

public final class CenterPresenter implements AnyNodePresenter, View.OnClickListener {

  public CenterPresenter(Activity activity) {
    this.activity = activity;

    imageLoader = ImageLoader.createWithBitmapFormatter(
        new ImageLoader.BitmapFormatter() {
          @Override
          public Bitmap formatBitmap(Bitmap bitmap) {
            final Bitmap output =
                Bitmap.createBitmap(bitmap.getWidth(), bitmap.getHeight(), Bitmap.Config.ARGB_8888);
            final Canvas canvas = new Canvas(output);
            final Paint paint = new Paint();
            paint.setAntiAlias(true);
            paint.setShader(new BitmapShader(bitmap, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP));
            canvas.drawOval(new RectF(0, 0, bitmap.getWidth(), bitmap.getHeight()), paint);
            return output;
          }
        },
        BitmapFactory.decodeResource(activity.getResources(), R.drawable.dart_logo));

    commitListPresenter = new CommitListAdapter(imageLoader);
  }

  @Override
  public void present(AnyNode node) {
    if (node.is(SlidingWindowNode.class)) {
      recyclerViewFragment = new RecyclerViewFragment();
      recyclerViewFragment.setRecyclerViewAdapter(commitListPresenter);
      addFragment(recyclerViewFragment);
      commitListPresenter.present(node.as(SlidingWindowNode.class));
    }
  }

  @Override
  public void patch(AnyNodePatch patch) {

    if (patch.is(SlidingWindowPatch.class)) {
      // TODO(zarah): Update SlidingWindow in graph to contain information on selected items.
      SlidingWindowPatch slidingWindowPatch = patch.as(SlidingWindowPatch.class);
      if (slidingWindowPatch.getWindow().hasChanged()) {
        for (ListPatch.RegionPatch region : slidingWindowPatch.getWindow().getRegions()) {
          if (region.isUpdate()) {
            for (NodePatch nodePatch : ((ListPatch.UpdatePatch) region).getUpdates()) {
              CommitPatch commitPatch = ((AnyNodePatch) nodePatch).as(CommitPatch.class);
              if (commitPatch.getSelected().hasChanged()) {
                if (commitPatch.getSelected().getCurrent() == true) {
                  select(commitListPresenter.windowIndexToViewPosition(region.getIndex()));
                  final FragmentManager fm = activity.getFragmentManager();
                  final int stackSize = fm.getBackStackEntryCount();
                  replaceFragment(createDetailsFragment(), true);
                  // TODO(zerny): Drive the deselect via the presentation graph.
                  fm.addOnBackStackChangedListener(new FragmentManager.OnBackStackChangedListener() {
                    @Override
                    public void onBackStackChanged() {
                      if (fm.getBackStackEntryCount() == stackSize) {
                        if (selectedIndex >= 0) commitListPresenter.toggle(selectedIndex);
                        fm.removeOnBackStackChangedListener(this);
                      }
                    }
                  });
                } else {
                  replaceFragment(recyclerViewFragment, false);
                  deselect(selectedIndex);
                }
              }
            }
          }
        }
      }
      commitListPresenter.patch(slidingWindowPatch);
    }
  }

  public void onClick(View view) {
    assert (selectedIndex >= 0);
    commitListPresenter.toggle(selectedIndex);
  }

  private DetailsViewFragment createDetailsFragment() {
    RecyclerView recyclerView = recyclerViewFragment.getRecyclerView();
    CommitListAdapter.CommitViewHolder holder =
        (CommitListAdapter.CommitViewHolder) recyclerView.findViewHolderForPosition(selectedIndex);
    
    DetailsViewFragment detailsViewFragment = new DetailsViewFragment();
    detailsViewFragment.setArguments(holder.getCardView().prepareDetailsFragmentArgs());
    detailsViewFragment.setOnClickListener(this);
    detailsViewFragment.setImageLoader(imageLoader);
    // TODO(zarah): use shared element transition on enter animation.
    detailsViewFragment.setEnterTransition(new Slide());

    return detailsViewFragment;
  }

  private void select(int index) {
    assert (selectedIndex == -1);
    selectedIndex = index;
    // TODO(zerny): Fix the "restore selected item" issue and enable rotation.
    activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LOCKED);
  }

  private void deselect(int position) {
    assert(position == selectedIndex);
    selectedIndex = -1;
    // TODO(zerny): Fix the "restore selected item" issue and enable rotation.
    activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED);
  }

  private void addFragment(Fragment fragment) {
    assert currentViewFragment == null;
    currentViewFragment = fragment;
    FragmentTransaction transaction = activity.getFragmentManager().beginTransaction();
    transaction.replace(R.id.container, fragment);
    transaction.commit();
  }

  private void replaceFragment(Fragment fragment, boolean addToBackStack) {
    if (currentViewFragment == fragment) return;
    currentViewFragment = fragment;
    FragmentTransaction transaction = activity.getFragmentManager().beginTransaction();
    transaction.replace(R.id.container, fragment);
    if (addToBackStack) {
      transaction.addToBackStack(DETAILS_VIEW_BACK_STACK_ENTRY);
    } else {
      FragmentManager fm = activity.getFragmentManager();
      fm.popBackStack(DETAILS_VIEW_BACK_STACK_ENTRY, FragmentManager.POP_BACK_STACK_INCLUSIVE);
    }
    transaction.commit();
  }

  private int selectedIndex;
  private Activity activity;
  private SlidingWindow commitListPresenter;
  private ImageLoader imageLoader;
  private RecyclerViewFragment recyclerViewFragment;
  private Fragment currentViewFragment;

  static private final String DETAILS_VIEW_BACK_STACK_ENTRY = "details_card_view_back";
}