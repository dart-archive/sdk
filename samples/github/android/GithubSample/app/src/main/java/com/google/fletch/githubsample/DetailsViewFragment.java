// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.app.Fragment;
import android.os.Bundle;
import android.support.v7.widget.CardView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

public class DetailsViewFragment extends Fragment {

  final static String AUTHOR = "Author";
  final static String TITLE = "Title";
  final static String DETAILS = "Details";
  final static String IMAGE_URL = "Bitmap";

  @Override
  public View onCreateView(LayoutInflater inflater, ViewGroup container,
                           Bundle savedInstanceState) {
    view = inflater.inflate(R.layout.details_view, container, false);
    CardView card = (CardView) view.findViewById(R.id.details_card_view);
    card.setOnClickListener(onClickListener);

    Bundle arguments = getArguments();
    configureCard(
        arguments.getString(IMAGE_URL),
        arguments.getString(TITLE),
        arguments.getString(AUTHOR),
        arguments.getString(DETAILS));

    return view;
  }

  public void setOnClickListener(View.OnClickListener listener) {
    onClickListener = listener;
  }

  public void setImageLoader(ImageLoader imageLoader) {
    this.imageLoader = imageLoader;
  }

  private void configureCard(String url, String title, String author, String details) {
    ImageView avatar = (ImageView) view.findViewById(R.id.details_avatar);
    imageLoader.loadImageFromUrl(avatar, url, IMAGE_VIEW_DIMENSION_PX, IMAGE_VIEW_DIMENSION_PX);
    TextView titleView = (TextView) view.findViewById(R.id.details_title);
    titleView.setText(title);
    TextView authorView = (TextView) view.findViewById(R.id.details_author);
    authorView.setText(author);
    TextView detailsView = (TextView) view.findViewById(R.id.details);
    detailsView.setText(details);
  }

  private static final int IMAGE_VIEW_DIMENSION_PX = 120;

  private View view;
  private View.OnClickListener onClickListener;
  private ImageLoader imageLoader;

}