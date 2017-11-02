'use strict'

const fs = require('fs')

// very test

const base = '/home/user/Music/lossless'

var explorer = { name: '/'
  , extended: true
  // Custom function used to recursively determine the node path
  , getPath: function(self){
      // If we don't have any parent, we are at tree root, so return the base case
      if(! self.parent)
        return '';
      // Get the parent node path and add this node name
      return self.parent.getPath(self.parent)+'/'+self.name;
    }
  // Child generation function
  , children: function(self){
      var result = {};
      var selfPath = self.getPath(self);
      try {
        // List files in this directory
        var children = fs.readdirSync(selfPath+'/');

        // childrenContent is a property filled with self.children() result
        // on tree generation (tree.setData() call)
        if (!self.childrenContent) {
          for(var child in children){
            child = children[child];
            var completePath = selfPath+'/'+child;
            if( fs.lstatSync(completePath).isDirectory() ){
              // If it's a directory we generate the child with the children generation function
              result[child] = { name: child, getPath: self.getPath, extended: false, children: self.children };
            }else{
              // Otherwise children is not set (you can also set it to "{}" or "null" if you want)
              result[child] = { name: child, getPath: self.getPath, extended: false };
            }
          }
        }else{
          result = self.childrenContent;
        }
      } catch (e){}
      return result;
    }
}

console.log(explorer);

// fs.readdir(base, (err, files) => {
//   if (err) throw err
//   processDir(files)
// })
