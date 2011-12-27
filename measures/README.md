This project will provide a library of quality measure definitions.  It is meant to provide measure definitions into the generic quality measure engine project, that is available at (https://github.com/pophealth/quality-measure-engine).

Environment
-----------

This project currently uses Ruby 1.9.2 and is built using [Bundler](http://gembundler.com/). To get all of the dependencies for the project, first install bundler:

    gem install bundler

Then run bundler to grab all of the necessary gems:

    bundle install

The Quality Measure engine relies on a MongoDB [MongoDB](http://www.mongodb.org/) running a minimum of version 1.6.* or higher.  To get and install Mongo refer to :

	http://www.mongodb.org/display/DOCS/Quickstart

Project Practices
------------------

Please try to follow our [Coding Style Guides](http://github.com/eedrummer/styleguide). Additionally, we will be using git in a pattern similar to [Vincent Driessen's workflow](http://nvie.com/posts/a-successful-git-branching-model/). While feature branches are encouraged, they are not required to work on the project.
