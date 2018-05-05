package com.tourpal.controller;

import java.util.List;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;

import com.alibaba.fastjson.JSON;
import com.tourpal.model.Message;
import com.tourpal.model.User;
import com.tourpal.service.UserService;

@Controller
@RequestMapping("/userController")
public class UserController {
	
	@Autowired
	private UserService userService;
	
	@RequestMapping("/{id}/showUser")
	public String showUser(@PathVariable String id, HttpServletRequest request, HttpServletResponse response){
		User user = userService.getUserById(id);
		request.setAttribute("user", user);
		return "showUser";
	}
	
	@RequestMapping("/user/showUser")
	public String showUser(){
		return "showUser";
	}
	
// 	@RequestMapping("/{id}/showUser")
// 	@ResponseBody
// 	public User showUser(@PathVariable Long id){
// 		return userService.getUserById(id);
// 	}
	
	@RequestMapping("/user/info")
	public String showUserInfo(){
		return "userInfo";
	}
	
	@RequestMapping("/user/all")
	@ResponseBody
	public List<User> findAll(){
		return userService.getAll2();
	}
	
	@RequestMapping("/user/del")
	@ResponseBody
    public Message deleteByPrimaryKey(Long userNumber){
    	return userService.deleteByPrimaryKey(userNumber);
    }
	
	@RequestMapping(value="/user/update",method=RequestMethod.POST )
	@ResponseBody
    public Message updateByPrimaryKeySelective(@RequestBody User user){
		System.out.println("******************************************************");
    	return userService.updateByPrimaryKeySelective(user);
    }
	
	@RequestMapping("/user/add")
	@ResponseBody
    public Message insertSelective(@RequestBody User user){
		Message message = userService.insertSelective(user);
		System.out.println("message:"+JSON.toJSONString(message));
    	return message;
    }
	
	@RequestMapping("/user/testMultithreading")
	@ResponseBody
	public Message testMultithreading(){
		return userService.testMultithreading();
	}
	
	@RequestMapping("/user/testMultithreading2")
	@ResponseBody
	public Message testMultithreading2(){
		return userService.testMultithreading2();
	}
	
	@RequestMapping("/user/testMultithreading3")
	@ResponseBody
	public Message testMultithreading3(){
		return userService.testMultithreading3();
	}
}
