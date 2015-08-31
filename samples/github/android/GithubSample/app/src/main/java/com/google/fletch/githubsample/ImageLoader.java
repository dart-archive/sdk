// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.os.AsyncTask;
import android.os.Looper;
import android.util.LruCache;
import android.widget.ImageView;

import java.io.InputStream;
import java.lang.ref.WeakReference;
import java.net.URL;


public class ImageLoader {

  private LruCache<String, Bitmap> imageCache;
  private BitmapFormatter bitmapFormatter;

  private ImageLoader(BitmapFormatter bitmapFormatter) {
    this.bitmapFormatter = bitmapFormatter;
    imageCache = new LruCache<String, Bitmap>(100);
  }

  public ImageLoader() {
    this(new BitmapFormatter() {
      @Override
      public Bitmap formatBitmap(Bitmap bitmap) {
        return bitmap;
      }
    });
  }

  public static ImageLoader createWithBitmapFormatter(BitmapFormatter bitmapFormatter) {
    return new ImageLoader(bitmapFormatter);
  }

  public void loadImageFromUrl(ImageView imageView, String url) {
    // This method should be called on the UI thread since it is setting the drawable on imageView.
    assert (Looper.getMainLooper() == Looper.myLooper());

    Bitmap bitmap = getFromCache(url);
    if (bitmap != null) {
      cancelPotentialWork(url, imageView);
      imageView.setImageBitmap((Bitmap) bitmap);
    } else {
      if (cancelPotentialWork(url, imageView)) {
        final BitmapDownloadTask task = new BitmapDownloadTask(imageView);
        final AsyncDrawable asyncDrawable =
            new AsyncDrawable(imageView.getResources(),
                              BitmapFactory.decodeResource(imageView.getResources(),
                                                           R.drawable.dart_logo),
                              task);
        imageView.setImageDrawable(asyncDrawable);
        task.execute(url);
      }
    }
  }

  public interface BitmapFormatter {

    public Bitmap formatBitmap(Bitmap bitmap);
  }

  private Bitmap getFromCache(String key) {
    synchronized (imageCache) {
      return imageCache.get(key);
    }
  }

  private void putInCache(String key, Bitmap bitmap) {
    synchronized (imageCache) {
      imageCache.put(key, bitmap);
    }
  }

  // Returns true if no task is associated with the imageView or if a task is already downloading a
  // different bitmap in which case the existing task is canceled.
  private boolean cancelPotentialWork(String url, ImageView imageView) {
    final BitmapDownloadTask bitmapDownloadTask = getDownloadTask(imageView);

    if (bitmapDownloadTask != null) {
      final String bitmapUrl = bitmapDownloadTask.url;
      if (bitmapUrl != null && bitmapUrl.equals(url)) return false;
      bitmapDownloadTask.cancel(true);
    }
    return true;
  }

  private BitmapDownloadTask getDownloadTask(ImageView imageView) {
    if (imageView != null) {
      final Drawable drawable = imageView.getDrawable();
      if (drawable instanceof AsyncDrawable) {
        final AsyncDrawable asyncDrawable = (AsyncDrawable) drawable;
        return asyncDrawable.getBitmapWorkerTask();
      }
    }
    return null;
  }

  static class AsyncDrawable extends BitmapDrawable {

    private final WeakReference<BitmapDownloadTask> bitmapWorkerTaskReference;

    public AsyncDrawable(Resources res, Bitmap bitmap,
                         BitmapDownloadTask bitmapDownloadTask) {
      super(res, bitmap);
      bitmapWorkerTaskReference =
          new WeakReference<BitmapDownloadTask>(bitmapDownloadTask);
    }

    public BitmapDownloadTask getBitmapWorkerTask() {
      return bitmapWorkerTaskReference.get();
    }
  }

  private class BitmapDownloadTask extends AsyncTask<String, Void, Bitmap> {

    public String url;
    public WeakReference<ImageView> imageViewReference;

    public BitmapDownloadTask(ImageView view) {
      imageViewReference = new WeakReference<ImageView>(view);
    }

    @Override
    protected Bitmap doInBackground(String... params) {
      url = params[0];
      Bitmap bitmap = null;
      try {
        bitmap = BitmapFactory.decodeStream((InputStream) new URL(url).getContent());
      } catch (Exception e) {
        e.printStackTrace();
      }

      Bitmap formattedBitmap = bitmapFormatter.formatBitmap(bitmap);
      putInCache(url, formattedBitmap);
      return formattedBitmap;
    }

    @Override
    protected void onPostExecute(Bitmap bitmap) {

      if (isCancelled()) {
        return;
      }

      if (imageViewReference != null && bitmap != null) {
        final ImageView imageView = imageViewReference.get();
        final BitmapDownloadTask task = getDownloadTask(imageView);
        if (this == task && imageView != null) {
          imageView.setImageBitmap(bitmap);
        }
      }
    }
  }
}