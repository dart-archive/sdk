// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.support.v7.widget.CardView;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import java.util.List;

public class RecyclerViewAdapter extends RecyclerView.Adapter<RecyclerViewAdapter.CommitViewHolder>{

  List<Commit> commitList;
  ImageLoader imageLoader;

  private static final int IMAGE_VIEW_DIMENSION_PX = 120;

  RecyclerViewAdapter(List<Commit> commitList, ImageLoader imageLoader) {
    this.commitList = commitList;
    this.imageLoader = imageLoader;
  }

  @Override
  public CommitViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
    View view =
        LayoutInflater.from(parent.getContext()).inflate(R.layout.cards_layout, parent, false);
    return new CommitViewHolder(view);
  }

  @Override
  public void onBindViewHolder(CommitViewHolder holder, int position) {
    holder.author.setText(commitList.get(position).author);
    holder.title.setText(commitList.get(position).title);
    imageLoader.loadImageFromUrl(holder.avatar, commitList.get(position).imageUrl,
        IMAGE_VIEW_DIMENSION_PX, IMAGE_VIEW_DIMENSION_PX);
    holder.cardView.setCommitItem(commitList.get(position));
  }

  @Override
  public int getItemCount() {
    return commitList.size();
  }

  @Override
  public void onAttachedToRecyclerView(RecyclerView recyclerView) {
    super.onAttachedToRecyclerView(recyclerView);
  }

  public static class CommitViewHolder extends RecyclerView.ViewHolder {

    CommitCardView cardView;
    TextView author;
    TextView title;
    ImageView avatar;

    public CommitViewHolder(View itemView) {
      super(itemView);
      cardView = (CommitCardView)itemView.findViewById(R.id.card_view);
      author = (TextView)itemView.findViewById(R.id.author);
      title = (TextView)itemView.findViewById(R.id.title);
      avatar = (ImageView)itemView.findViewById(R.id.avatar);
    }
  }
}
