// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.app.Activity;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.BitmapShader;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Shader;
import android.support.v7.widget.DefaultItemAnimator;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;

import com.google.fletch.immisamples.SlidingWindow;

import immi.AnyNode;
import immi.AnyNodePatch;
import immi.AnyNodePresenter;
import immi.SlidingWindowNode;
import immi.SlidingWindowPatch;

public final class CenterPresenter implements AnyNodePresenter {

  public CenterPresenter(Activity activity) {
    RecyclerView recyclerView = (RecyclerView) activity.findViewById(R.id.recycler_view);
    // As long as the adapter does not cause size changes, this is set to true to gain performance.
    recyclerView.setHasFixedSize(true);
    recyclerView.setItemAnimator(new DefaultItemAnimator());
    recyclerView.setLayoutManager(new LinearLayoutManager(activity));

    ImageLoader imageLoader = ImageLoader.createWithBitmapFormatter(
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

    presenter = new RecyclerViewAdapter(imageLoader);
    recyclerView.setAdapter(presenter);
  }

  @Override
  public void present(AnyNode node) {
    presenter.present(node.as(SlidingWindowNode.class));
  }

  @Override
  public void patch(AnyNodePatch patch) {
    presenter.patch(patch.as(SlidingWindowPatch.class));
  }

  private SlidingWindow presenter;
}
