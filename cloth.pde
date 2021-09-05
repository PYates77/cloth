ArrayList<Point> points;
ArrayList<Stick> sticks;
boolean simulation_enable;

boolean dragging = false;

boolean drawing_sticks = false;
Stick dragStick;

boolean selection = false;
Point selectedPoint;

final PVector GRAVITY = new PVector(0, 9.8/60);
final int SIM_ITERATIONS = 100;

class Point {
  PVector pos, ppos; /* Previous position */
  boolean locked;
  float radius;
  // TODO: mass?

  /* Keep a list of neighbors so we don't create duplicate sticks */
  ArrayList<Point> neighbors; 

  Point(float x, float y) {
    pos = new PVector(x, y);
    ppos = new PVector(x, y);
    radius = 10;
    locked = false;
    neighbors = new ArrayList<Point>();
  }

  void addNeighbor(Point p) {
    neighbors.add(p);
  }

  void removeNeighbor(Point p) {
    neighbors.remove(p);
  }

  boolean hasNeighbor(Point p) {
    return neighbors.contains(p);
  }

  boolean inside(float x, float y) {
    PVector p = new PVector(x, y);
    return (pos.dist(p) < radius);
  }

  void draw() {
    if (locked) {
      fill(255,0,0);
    } else {
      fill(255);
    }
    circle(pos.x, pos.y, radius);
  }
}

class Stick {
  Point p1, p2;
  float len;

  Stick(Point a, Point b) {
    p1 = a;
    p2 = b;

    a.addNeighbor(b);
    b.addNeighbor(a);

    len = a.pos.dist(b.pos);
  }

  Stick() {
    /* Need to have a constructor that leaves points undefined */
  }

  void draw() {
    line(p1.pos.x, p1.pos.y, p2.pos.x, p2.pos.y);
  }

  int orientation(PVector p, PVector q, PVector r) {
    float val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);
    if (val < 0) {
      return 1;
    } else if (val > 0) {
      return 2;
    } 

    return 0;
  }

  boolean intersecting(Stick s) {
    int o1 = orientation(p1.pos, p2.pos, s.p1.pos);
    int o2 = orientation(p1.pos, p2.pos, s.p2.pos);
    int o3 = orientation(s.p1.pos, s.p2.pos, p1.pos);
    int o4 = orientation(s.p1.pos, s.p2.pos, p2.pos);

    if (o1 != o2 && o3 != o4) {
      return true;
    }

    return false;
  }
}

void simulate() {
  for (int i=0; i<points.size(); i++) {
    Point p = points.get(i);
    if (!p.locked) {
      PVector prev = p.pos.copy();
      PVector dx = PVector.sub(p.pos, p.ppos);
      p.pos.add(dx);
      p.pos.add(GRAVITY);
      p.ppos = prev;
    } else {
      p.ppos = p.pos;
    }
  }

  for (int sim=0; sim < SIM_ITERATIONS; sim++) {
    for (int i=0; i<sticks.size(); i++) {
      Stick s = sticks.get(i);
      Point p1 = s.p1;
      Point p2 = s.p2;

      PVector center = PVector.div(PVector.add(p1.pos, p2.pos),2); // Center by averaging positions

      /* Snap points to the end of their sticks */
      if (!p1.locked) {
        /* I mean I don't _like_ operator override, but throw me a bone here! */
        p1.pos = PVector.add(center, PVector.mult(PVector.sub(p1.pos, center).normalize(), s.len/2));
      }

      if (!p2.locked) {
        p2.pos = PVector.add(center, PVector.mult(PVector.sub(p2.pos, center).normalize(), s.len/2));
      }
    }
  }
}

void draw() {
  background(255/2);

  if (simulation_enable) {
    simulate();
  }

  for (int i=0; i<sticks.size(); i++) {
    sticks.get(i).draw();
  }

  for (int i=0; i<points.size(); i++) {
    points.get(i).draw();
  }

  if (drawing_sticks) {
    dragStick.draw();
  }

}

void setup() {
  //GRAVITY = new PVector(0, 9.8/60);
  points = new ArrayList<Point>();
  sticks = new ArrayList<Stick>();
  dragStick = new Stick();
  simulation_enable = false;
  size(640, 560);
  frameRate(60);
}

void mousePressed() {
  /* If mouse pressed inside a point, start drawing sticks */
  for (int i=0; i<points.size(); i++) {
    Point p = points.get(i);
    if (p.inside(mouseX, mouseY)) {
      selection = true;
      selectedPoint = p;
      dragStick.p1 = p;
      dragStick.p2 = new Point(mouseX, mouseY);
      return;
    }
  }

  /* Otherwise, start cutting sticks */
  dragStick.p1 = new Point(mouseX, mouseY);
}

void mouseDragged() {
  /* Determine whether we need to enter the stick drawing state */
  dragging = true;
  if (selection) {
    //dragStick.p1 = selectedPoint;
    //dragStick.p2 = new Point(mouseX, mouseY);
    selection = false;
    drawing_sticks = true;
  }

  if (drawing_sticks) {
    /* Attach sticks to any points we drag through */
    for (int i=0; i<points.size(); i++) {
      Point p = points.get(i);
      if (p.inside(mouseX, mouseY)) {
        if (dragStick.p1 != p && !p.hasNeighbor(dragStick.p1)) {
          sticks.add(new Stick(dragStick.p1, p));
          dragStick.p1 = p;
        }
      } 
    }
    dragStick.p2 = new Point(mouseX, mouseY); // Much garbage collection, wow
  } else {
    /* If we're dragging the mouse around but not drawing sticks, we can cut sticks */
    dragStick.p2 = new Point(mouseX, mouseY);
    for (int i=0; i<sticks.size(); i++) {
      Stick s = sticks.get(i);
      if (s.intersecting(dragStick)) {
        s.p1.removeNeighbor(s.p2);
        s.p2.removeNeighbor(s.p1);
        sticks.remove(s);
        break;
      }
    }
    dragStick.p1 = dragStick.p2;
  }
}

void mouseReleased() {
  if (!dragging) {
    if (selection) {
      selectedPoint.locked = !selectedPoint.locked;
      selection = false;
    } else {
      points.add(new Point(mouseX, mouseY));
    }
  }
  dragging = false;
  drawing_sticks = false;
}

void keyPressed() {
  if (key == ' ') {
    simulation_enable = !simulation_enable;
  }
}
