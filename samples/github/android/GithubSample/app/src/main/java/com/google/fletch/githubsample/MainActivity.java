// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

package com.google.fletch.githubsample;

import android.app.Activity;

import android.app.ActionBar;
import android.app.ActivityOptions;
import android.app.Fragment;
import android.app.FragmentManager;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.BitmapShader;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Shader;
import android.os.Bundle;
import android.transition.Explode;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.support.v4.widget.DrawerLayout;
import android.support.v7.widget.RecyclerView;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.DefaultItemAnimator;

import immi.AnyNode;
import immi.AnyNodePatch;
import immi.AnyNodePresenter;
import immi.DrawerNode;
import immi.DrawerPatch;
import immi.ImmiRoot;
import immi.ImmiService;

public class MainActivity extends Activity
    implements NavigationDrawerFragment.NavigationDrawerCallbacks, AnyNodePresenter {

  public void presentNode(AnyNode node) {
    DrawerNode drawer = node.as(DrawerNode.class);
    drawer.getToggleLeft().dispatch();
  }

  public void patchNode(AnyNodePatch patch) {
    DrawerPatch drawer = patch.as(DrawerPatch.class);
    if (drawer.getLeftVisible().hasChanged()) {
      // TODO(zerny): Toggle the drawer etc.
    }
  }

  /**
   * Fragment managing the behaviors, interactions and presentation of the navigation drawer.
   */
  private NavigationDrawerFragment navigationDrawerFragment;

  /**
   * Used to store the last screen title. For use in {@link #restoreActionBar()}.
   */
  private CharSequence title;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.activity_main);

    navigationDrawerFragment = (NavigationDrawerFragment)
        getFragmentManager().findFragmentById(R.id.navigation_drawer);
    title = getTitle();

    // Set up the drawer.
    navigationDrawerFragment.setUp(
        R.id.navigation_drawer,
        (DrawerLayout) findViewById(R.id.drawer_layout));

    RecyclerView recyclerView = (RecyclerView) findViewById(R.id.recycler_view);
    // As long as the adapter does not cause size changes, this is set to true to gain performance.
    recyclerView.setHasFixedSize(true);
    recyclerView.setItemAnimator(new DefaultItemAnimator());

    LinearLayoutManager layoutManager = new LinearLayoutManager(this);
    recyclerView.setLayoutManager(layoutManager);


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
        BitmapFactory.decodeResource(getResources(), R.drawable.dart_logo));

    RecyclerViewAdapter adapter = new RecyclerViewAdapter(new CommitList().commitList,
        imageLoader);
    recyclerView.setAdapter(adapter);

    ImmiService immi = new ImmiService();
    ImmiRoot root = immi.registerPresenter(this, "DrawerPresenter");
    root.refresh();
  }

  @Override
  public void onNavigationDrawerItemSelected(int position) {
    // update the main content by replacing fragments
    FragmentManager fragmentManager = getFragmentManager();
    fragmentManager.beginTransaction()
        .replace(R.id.container, PlaceholderFragment.newInstance(position + 1))
        .commit();
  }

  public void onSectionAttached(int number) {
    switch (number) {
      case 1:
        title = getString(R.string.title_section1);
        break;
      case 2:
        title = getString(R.string.title_section2);
        break;
      case 3:
        title = getString(R.string.title_section3);
        break;
    }
  }

  public void restoreActionBar() {
    ActionBar actionBar = getActionBar();
    actionBar.setNavigationMode(ActionBar.NAVIGATION_MODE_STANDARD);
    actionBar.setDisplayShowTitleEnabled(true);
    actionBar.setTitle(title);
  }


  @Override
  public boolean onCreateOptionsMenu(Menu menu) {
    if (!navigationDrawerFragment.isDrawerOpen()) {
      // Only show items in the action bar relevant to this screen
      // if the drawer is not showing. Otherwise, let the drawer
      // decide what to show in the action bar.
      getMenuInflater().inflate(R.menu.menu_main, menu);
      restoreActionBar();
      return true;
    }
    return super.onCreateOptionsMenu(menu);
  }

  @Override
  public boolean onOptionsItemSelected(MenuItem item) {
    // Handle action bar item clicks here. The action bar will
    // automatically handle clicks on the Home/Up button, so long
    // as you specify a parent activity in AndroidManifest.xml.
    int id = item.getItemId();

    //noinspection SimplifiableIfStatement
    if (id == R.id.action_settings) {
      return true;
    }

    return super.onOptionsItemSelected(item);
  }

  public void showDetails(View view) {
    Intent intent = new Intent(this, DetailsViewActivity.class);
    ActivityOptions options =
        ActivityOptions.makeSceneTransitionAnimation(this, view, "transition_card");
    getWindow().setExitTransition(new Explode());
    startActivity(intent, options.toBundle());
  }

  /**
   * A placeholder fragment containing a simple view.
   */
  public static class PlaceholderFragment extends Fragment {
    /**
     * The fragment argument representing the section number for this
     * fragment.
     */
    private static final String ARG_SECTION_NUMBER = "section_number";

    /**
     * Returns a new instance of this fragment for the given section
     * number.
     */
    public static PlaceholderFragment newInstance(int sectionNumber) {
      PlaceholderFragment fragment = new PlaceholderFragment();
      Bundle args = new Bundle();
      args.putInt(ARG_SECTION_NUMBER, sectionNumber);
      fragment.setArguments(args);
      return fragment;
    }

    public PlaceholderFragment() {
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
                             Bundle savedInstanceState) {
      View rootView = inflater.inflate(R.layout.fragment_main, container, false);
      return rootView;
    }

    @Override
    public void onAttach(Activity activity) {
      super.onAttach(activity);
      ((MainActivity) activity).onSectionAttached(
          getArguments().getInt(ARG_SECTION_NUMBER));
    }
  }

}
