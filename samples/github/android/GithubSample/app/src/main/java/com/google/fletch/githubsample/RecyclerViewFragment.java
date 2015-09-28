package com.google.fletch.githubsample;

import android.app.Fragment;
import android.os.Bundle;
import android.support.v7.widget.DefaultItemAnimator;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

public class RecyclerViewFragment extends Fragment {

  RecyclerView recyclerView;
  RecyclerView.Adapter adapter;

  @Override
  public View onCreateView(LayoutInflater inflater, ViewGroup container,
                           Bundle savedInstanceState) {
    View view = inflater.inflate(R.layout.recycler_view, container, false);
    recyclerView = (RecyclerView) view.findViewById(R.id.recycler_view);
    // As long as the adapter does not cause size changes, this is set to true to gain performance.
    recyclerView.setHasFixedSize(true);
    recyclerView.setItemAnimator(new DefaultItemAnimator());
    recyclerView.setLayoutManager(new LinearLayoutManager(getActivity()));
    recyclerView.setAdapter(adapter);
    return view;
  }

  public RecyclerView getRecyclerView() {
    return recyclerView;
  }
  
  public void setRecyclerViewAdapter(RecyclerView.Adapter adapter) {
    this.adapter = adapter;
  }
}