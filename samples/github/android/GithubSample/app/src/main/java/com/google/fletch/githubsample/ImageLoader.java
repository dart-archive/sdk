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

import java.io.IOException;
import java.io.InputStream;
import java.lang.ref.WeakReference;
import java.net.URL;


public class ImageLoader {

  private LruCache<String, Bitmap> imageCache;
  private BitmapFormatter bitmapFormatter;
  private Bitmap defaultBitmap;

  private ImageLoader(BitmapFormatter bitmapFormatter, Bitmap defaultBitmap) {
    this.bitmapFormatter = bitmapFormatter;
    this.defaultBitmap = defaultBitmap;
    imageCache = new LruCache<String, Bitmap>(100);
  }

  public ImageLoader(Bitmap defaultBitmap) {
    this(new BitmapFormatter() {
      @Override
      public Bitmap formatBitmap(Bitmap bitmap) {
        return bitmap;
      }
    }, defaultBitmap);
  }

  public static ImageLoader createWithBitmapFormatter(BitmapFormatter bitmapFormatter,
                                                      Bitmap defaultBitmap) {
    return new ImageLoader(bitmapFormatter, defaultBitmap);
  }

  public void loadImageFromUrl(
      ImageView imageView, String url, int imageViewWidth, int imageViewHeight) {
    // This method should be called on the UI thread since it is setting the drawable on imageView.
    assert (Looper.getMainLooper() == Looper.myLooper());

    if (url == null || url.isEmpty()) {
      imageView.setImageBitmap(defaultBitmap);
      return;
    }

    Bitmap bitmap = getFromCache(url);
    if (bitmap != null) {
      cancelPotentialWork(url, imageView);
      imageView.setImageBitmap((Bitmap) bitmap);
    } else {
      if (cancelPotentialWork(url, imageView)) {
        final BitmapDownloadTask task =
            new BitmapDownloadTask(imageView, imageViewWidth, imageViewHeight);
        final AsyncDrawable asyncDrawable =
            new AsyncDrawable(imageView.getResources(), defaultBitmap, task);
        imageView.setImageDrawable(asyncDrawable);
        task.execute(url);
      }
    }
  }

  public interface BitmapFormatter {

    Bitmap formatBitmap(Bitmap bitmap);
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
    public int imageViewHeight;
    public int imageViewWidth;

    public BitmapDownloadTask(ImageView view, int imageViewWidth, int imageViewHeight) {
      imageViewReference = new WeakReference<ImageView>(view);
      this.imageViewHeight = imageViewHeight;
      this.imageViewWidth = imageViewWidth;
    }

    @Override
    protected Bitmap doInBackground(String... params) {
      url = params[0];
      Bitmap bitmap = null;

      BitmapFactory.Options options = new BitmapFactory.Options();
      options.inJustDecodeBounds = true;
      try (InputStream sizeInputStream = (InputStream) new URL(url).getContent();
           InputStream bitmapInputStream = (InputStream) new URL(url).getContent()) {

        BitmapFactory.decodeStream(sizeInputStream, null, options);
        options.inSampleSize = calculateInSampleSize(options, imageViewWidth, imageViewHeight);
        options.inJustDecodeBounds = false;
        bitmap = BitmapFactory.decodeStream(bitmapInputStream, null, options);

        Bitmap formattedBitmap = bitmapFormatter.formatBitmap(bitmap);
        putInCache(url, formattedBitmap);
        return formattedBitmap;
      } catch (IOException e) {
        e.printStackTrace();
        return defaultBitmap;
      }
    }

    private int calculateInSampleSize(
        BitmapFactory.Options options, int requiredWidth, int requiredHeight) {
      // Raw height and width of image
      final int height = options.outHeight;
      final int width = options.outWidth;

      if (height > requiredHeight || width > requiredWidth) {

        // Calculate ratios of height and width to requested height and width
        final int heightRatio = Math.round((float) height / (float) requiredHeight);
        final int widthRatio = Math.round((float) width / (float) requiredWidth);

        // Choose the smallest ratio as inSampleSize value, this will guarantee
        // a final image with both dimensions larger than or equal to the
        // requested height and width.
        return heightRatio < widthRatio ? heightRatio : widthRatio;
      }

      return 1;
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