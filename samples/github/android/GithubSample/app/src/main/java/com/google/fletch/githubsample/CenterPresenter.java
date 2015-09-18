// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.app.Activity;
import android.app.Fragment;
import android.app.FragmentTransaction;
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
      for (ListPatch.RegionPatch region : slidingWindowPatch.getWindow().getRegions()) {
        if (region.isUpdate()) {
          for (NodePatch nodePatch : ((ListPatch.UpdatePatch) region).getUpdates()) {
            CommitPatch commitPatch = ((AnyNodePatch) nodePatch).as(CommitPatch.class);
            if (commitPatch.getSelected().hasChanged()) {
              if (commitPatch.getSelected().getCurrent() == true) {
                select(commitListPresenter.windowIndexToViewPosition(region.getIndex()));
                replaceFragment(createDetailsFragment());
              } else {
                deselect(selectedIndex);
                replaceFragment(recyclerViewFragment);
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
    RecyclerView recyclerView = (RecyclerView) activity.findViewById(R.id.recycler_view);
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
  }

  private void deselect(int position) {
    assert(position == selectedIndex);
    selectedIndex = -1;
  }

  private void addFragment(Fragment fragment) {
    FragmentTransaction transaction = activity.getFragmentManager().beginTransaction();
    transaction.add(R.id.container, fragment);
    transaction.addToBackStack(null);
    transaction.commit();
  }

  private void replaceFragment(Fragment fragment) {
    FragmentTransaction transaction = activity.getFragmentManager().beginTransaction();
    transaction.replace(R.id.container, fragment);
    transaction.commit();
  }

  private int selectedIndex;
  private Activity activity;
  private SlidingWindow commitListPresenter;
  private ImageLoader imageLoader;
  private RecyclerViewFragment recyclerViewFragment;
}